<?php

namespace Tests\Feature\Actions;

use App\Actions\CompleteAttendanceSession;
use App\Actions\OpenAttendanceSession;
use App\Actions\RecalculateCircleStats;
use App\Actions\ReviewAbsenceExcuse;
use App\Actions\TakeAttendance;
use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\ExcuseStatus;
use App\Models\AbsenceExcuse;
use App\Models\CircleDailyStat;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Collection;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class CircleStatsTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_circles_are_ranked_by_rate_descending_within_the_shift(): void
    {
        // ثلاث حلقات في الدوام نفسه بنِسب 100٪ و50٪ و0٪.
        $best = $this->circleWithAttendance(['present', 'present']);
        $middle = $this->circleWithAttendance(['present', 'absent']);
        $worst = $this->circleWithAttendance(['absent', 'absent']);

        $this->assertSame(1, $this->dailyRank($best));
        $this->assertSame(2, $this->dailyRank($middle));
        $this->assertSame(3, $this->dailyRank($worst));
    }

    /**
     * حراسةٌ على خلل حقيقي وقع: sortBy بمصفوفة إغلاقات يعامل كلّ إغلاق مقارِناً
     * بوسيطين ($a, $b) لا مستخرِجَ مفتاح. والإغلاق أحاديّ الوسيط يتجاهل $b ويعيد
     * قيمةً ثابتة الإشارة، فيصير المقارِن غير متّسق وتبقى المجموعة بترتيب الإدخال.
     *
     * الحلقة الأعلى نسبةً تُنشَأ أخيراً عمداً: لو بقي الترتيب ترتيبَ الإدخال
     * لحصلت على أسوأ رتبة — وهو بالضبط ما كان يحدث.
     */
    public function test_the_highest_rate_ranks_first_even_when_created_last(): void
    {
        $weakest = $this->circleWithAttendance(['present', 'absent', 'absent']);
        $middle = $this->circleWithAttendance(['present', 'present', 'absent']);
        $best = $this->circleWithAttendance(['present', 'present', 'present']);

        $this->assertEqualsWithDelta(33.33, (float) $this->dailyStat($weakest)->attendance_rate, 0.01);
        $this->assertEqualsWithDelta(66.67, (float) $this->dailyStat($middle)->attendance_rate, 0.01);
        $this->assertSame(100.0, (float) $this->dailyStat($best)->attendance_rate);

        $this->assertSame(1, $this->dailyRank($best));
        $this->assertSame(2, $this->dailyRank($middle));
        $this->assertSame(3, $this->dailyRank($weakest));
    }

    public function test_tied_circles_share_a_rank_and_the_next_rank_skips(): void
    {
        $a = $this->circleWithAttendance(['present', 'present']);
        $b = $this->circleWithAttendance(['present', 'present']);
        $c = $this->circleWithAttendance(['absent', 'absent']);

        $this->assertSame(1, $this->dailyRank($a));
        $this->assertSame(1, $this->dailyRank($b));
        $this->assertSame(3, $this->dailyRank($c));
    }

    public function test_excused_absences_do_not_lower_the_circle_rate(): void
    {
        $circle = $this->circleWithAttendance(['present', 'excused', 'excused']);

        // (حاضر 1 + متأخّر 0) ÷ (3 − 2) = 100٪
        $this->assertSame(100.0, (float) $this->dailyStat($circle)->attendance_rate);
    }

    public function test_a_session_with_only_excused_students_scores_zero_not_a_division_error(): void
    {
        $circle = $this->circleWithAttendance(['excused', 'excused']);

        $this->assertSame(0.0, (float) $this->dailyStat($circle)->attendance_rate);
    }

    public function test_recalculating_twice_does_not_duplicate_rows(): void
    {
        $circle = $this->circleWithAttendance(['present', 'absent']);

        app(RecalculateCircleStats::class)->handle($this->shift->id, '2026-09-01');
        app(RecalculateCircleStats::class)->handle($this->shift->id, '2026-09-01');

        $this->assertSame(1, $circle->dailyStats()->whereDate('date', '2026-09-01')->count());
        $this->assertSame(1, $circle->cumulativeStats()->whereDate('as_of_date', '2026-09-01')->count());
    }

    public function test_the_cumulative_stat_aggregates_every_day_up_to_the_date(): void
    {
        $circle = $this->makeCourseCircle();
        $students = $this->enroll($circle, 2);

        $this->takeAndComplete($circle, $students, ['present', 'present'], '2026-09-01');
        $this->takeAndComplete($circle, $students, ['present', 'absent'], '2026-09-02');

        $cumulative = $circle->cumulativeStats()->whereDate('as_of_date', '2026-09-02')->sole();

        $this->assertSame(2, $cumulative->sessions_count);
        $this->assertSame(3, $cumulative->present);
        $this->assertSame(1, $cumulative->absent);
        $this->assertSame(4, $cumulative->total);
        $this->assertSame(75.0, (float) $cumulative->attendance_rate);
    }

    public function test_approving_an_excuse_converts_absences_and_recomputes_the_rate(): void
    {
        $circle = $this->makeCourseCircle();
        $students = $this->enroll($circle, 2);

        $this->takeAndComplete($circle, $students, ['absent', 'present'], '2026-09-01');

        $this->assertSame(50.0, (float) $this->dailyStat($circle)->attendance_rate);

        $excuse = AbsenceExcuse::factory()->create([
            'student_id' => $students->first()->id,
            'from_date' => '2026-09-01',
            'to_date' => '2026-09-01',
            'status' => ExcuseStatus::Pending,
        ]);

        app(ReviewAbsenceExcuse::class)->handle($excuse, ExcuseStatus::Approved, $this->admin);

        // الغياب صار "مأذون"، فبقي حاضرٌ واحد على واحد محسوب = 100٪
        $this->assertSame(100.0, (float) $this->dailyStat($circle)->attendance_rate);
    }

    public function test_rejecting_an_excuse_leaves_the_attendance_untouched(): void
    {
        $circle = $this->makeCourseCircle();
        $students = $this->enroll($circle, 2);

        $this->takeAndComplete($circle, $students, ['absent', 'present'], '2026-09-01');

        $excuse = AbsenceExcuse::factory()->create([
            'student_id' => $students->first()->id,
            'from_date' => '2026-09-01',
            'to_date' => '2026-09-01',
            'status' => ExcuseStatus::Pending,
        ]);

        app(ReviewAbsenceExcuse::class)->handle($excuse, ExcuseStatus::Rejected, $this->admin);

        $this->assertSame(50.0, (float) $this->dailyStat($circle)->attendance_rate);
        $this->assertSame(ExcuseStatus::Rejected, $excuse->refresh()->status);
    }

    public function test_the_console_command_rebuilds_stats_for_a_course(): void
    {
        $circle = $this->circleWithAttendance(['present', 'absent']);

        $circle->dailyStats()->delete();
        $circle->cumulativeStats()->delete();

        $this->artisan('mousqe:recalculate-stats', ['--course' => $this->course->id])
            ->assertSuccessful();

        $this->assertSame(1, $circle->dailyStats()->count());
        $this->assertSame(1, $circle->cumulativeStats()->count());
    }

    /**
     * حلقة جديدة في الدوام نفسه، متفقَّدة ومغلقة في 2026-09-01.
     *
     * @param  array<int, string>  $statuses
     */
    private function circleWithAttendance(array $statuses): CourseCircle
    {
        $circle = $this->makeCourseCircle();
        $students = $this->enroll($circle, count($statuses));

        $this->takeAndComplete($circle, $students, $statuses, '2026-09-01');

        return $circle;
    }

    /**
     * @param  Collection<int, Student>  $students
     * @param  array<int, string>  $statuses
     */
    private function takeAndComplete(CourseCircle $circle, Collection $students, array $statuses, string $date): void
    {
        $session = app(OpenAttendanceSession::class)->handle($circle, $date, $this->admin);

        $rows = [];

        foreach ($students->values() as $index => $student) {
            $rows[$student->id] = ['status' => $statuses[$index] ?? AttendanceStatus::Present->value];
        }

        app(TakeAttendance::class)->handle($session, $rows, $this->admin);
        app(CompleteAttendanceSession::class)->handle($session->refresh(), $this->admin);
    }

    /**
     * @return Collection<int, Student>
     */
    private function enroll(CourseCircle $circle, int $count): Collection
    {
        return collect(range(1, $count))->map(function () use ($circle) {
            $student = Student::factory()->create(['institute_id' => $this->institute->id]);

            Enrollment::factory()->create([
                'course_circle_id' => $circle->id,
                'student_id' => $student->id,
                'status' => EnrollmentStatus::Active,
                'enrolled_on' => '2026-08-01',
            ]);

            return $student;
        });
    }

    private function dailyStat(CourseCircle $circle): CircleDailyStat
    {
        return $circle->dailyStats()->whereDate('date', '2026-09-01')->sole();
    }

    private function dailyRank(CourseCircle $circle): ?int
    {
        return $this->dailyStat($circle)->daily_rank_in_shift;
    }
}
