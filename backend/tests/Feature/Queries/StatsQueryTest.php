<?php

namespace Tests\Feature\Queries;

use App\Actions\RecalculateCircleStats;
use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\NotePolarity;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Queries\StatsQuery;
use App\Support\DateRange;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class StatsQueryTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $strong;

    private CourseCircle $weak;

    private Student $diligent;

    private Student $idle;

    private string $today;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->today = Carbon::today()->toDateString();

        $this->strong = $this->makeCourseCircle('حلقة الفاروق');
        $this->weak = $this->makeCourseCircle('حلقة الصدّيق');

        $this->diligent = $this->enroll($this->strong);
        $this->idle = $this->enroll($this->weak);

        $this->record($this->strong, $this->diligent, AttendanceStatus::Present, NotePolarity::Positive);
        $this->record($this->weak, $this->idle, AttendanceStatus::Absent, NotePolarity::Negative);

        MemorizationLog::factory()->create([
            'student_id' => $this->diligent->id,
            'course_circle_id' => $this->strong->id,
            'date' => $this->today,
            'new_lines' => 30,
        ]);
    }

    public function test_the_attendance_board_puts_the_present_circle_first(): void
    {
        $board = $this->board(StatsQuery::ENTITY_CIRCLES, StatsQuery::METRIC_ATTENDANCE);

        $this->assertSame('حلقة الفاروق', $board->first()['name']);
        $this->assertEqualsWithDelta(100.0, $board->first()['value'], 0.01);
        $this->assertEqualsWithDelta(0.0, $board->last()['value'], 0.01);
    }

    public function test_the_recitation_board_counts_new_lines_only(): void
    {
        $board = $this->board(StatsQuery::ENTITY_STUDENTS, StatsQuery::METRIC_RECITATION);

        $this->assertSame($this->diligent->id, $board->first()['id']);
        $this->assertEqualsWithDelta(30.0, $board->first()['value'], 0.01);
        $this->assertEqualsWithDelta(0.0, $board->last()['value'], 0.01);
    }

    public function test_the_points_board_ranks_by_the_total(): void
    {
        $board = $this->board(StatsQuery::ENTITY_STUDENTS, StatsQuery::METRIC_POINTS);

        $this->assertSame($this->diligent->id, $board->first()['id']);
        $this->assertGreaterThan($board->last()['value'], $board->first()['value']);
    }

    public function test_the_manners_metric_is_positive_notes_minus_negative_ones(): void
    {
        $board = $this->board(StatsQuery::ENTITY_STUDENTS, StatsQuery::METRIC_MANNERS);

        $this->assertEqualsWithDelta(1.0, $board->firstWhere('id', $this->diligent->id)['value'], 0.01);
        $this->assertEqualsWithDelta(-1.0, $board->firstWhere('id', $this->idle->id)['value'], 0.01);
        $this->assertSame($this->diligent->id, $board->first()['id']);
    }

    public function test_the_board_is_empty_without_a_course(): void
    {
        $this->assertTrue(
            app(StatsQuery::class)
                ->leaderboard(StatsQuery::ENTITY_CIRCLES, StatsQuery::METRIC_ATTENDANCE, $this->range(), null)
                ->isEmpty()
        );
    }

    private function board(string $entity, string $metric): Collection
    {
        return app(StatsQuery::class)->leaderboard($entity, $metric, $this->range(), $this->course);
    }

    private function range(): DateRange
    {
        return DateRange::make(DateRange::WEEK, $this->course);
    }

    private function enroll(CourseCircle $courseCircle): Student
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => '2026-08-01',
        ]);

        return $student;
    }

    private function record(CourseCircle $courseCircle, Student $student, AttendanceStatus $status, NotePolarity $polarity): void
    {
        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => $this->today,
            'status' => SessionStatus::Completed,
        ]);

        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => $status,
            'note' => 'ملاحظة',
            'note_polarity' => $polarity,
        ]);

        app(RecalculateCircleStats::class)->handle($courseCircle->shift_id, $this->today);
    }
}
