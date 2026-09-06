<?php

namespace Tests\Feature\Actions;

use App\Actions\AwardStudentPoints;
use App\Actions\CalculateStudentPoints;
use App\Actions\SaveRecitation;
use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\RecitationGrade;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentPoint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class StudentPointsTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    private AttendanceSession $session;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle();
        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $this->student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => '2026-08-01',
        ]);

        $this->session = AttendanceSession::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'session_date' => '2026-09-01',
            'status' => SessionStatus::Draft,
        ]);
    }

    public function test_a_locked_session_refuses_a_recitation(): void
    {
        $this->session->update(['status' => SessionStatus::Locked]);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('الجلسة مقفلة ولا تقبل التعديل.');

        $this->save(1, 30);
    }

    public function test_an_ayah_beyond_the_surah_is_rejected(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('رقم الآية خارج السورة');

        $this->save(1, 31);
    }

    public function test_the_end_of_a_range_cannot_precede_its_start(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('نهاية المدى قبل بدايته.');

        $this->save(20, 5);
    }

    public function test_repeating_a_stretch_adds_no_new_lines(): void
    {
        $first = $this->save(1, 12);
        $second = $this->save(1, 30);

        $this->assertEqualsWithDelta(12 / 30 * 31, (float) $first->new_lines, 0.01);
        $this->assertEqualsWithDelta(31.0, (float) $second->lines, 0.01);
        $this->assertEqualsWithDelta(18 / 30 * 31, (float) $second->new_lines, 0.01);
    }

    public function test_the_grade_multiplier_scales_the_points(): void
    {
        $excellent = $this->save(1, 15, RecitationGrade::Excellent);
        $good = $this->save(16, 30, RecitationGrade::Good);

        // النقاط = الأسطر الجديدة ÷ 15 × 10 × المعامل؛ والمدَيان متساويان في الآيات.
        $this->assertEqualsWithDelta(0.6, (float) $good->points / (float) $excellent->points, 0.01);
    }

    public function test_discretionary_points_accept_a_negative_value_with_or_without_a_session(): void
    {
        $penalty = app(AwardStudentPoints::class)->handle(
            $this->student,
            ['points' => -3, 'reason' => 'behavior', 'note' => 'مشاغبة'],
            $this->admin,
            $this->session,
        );

        $standalone = app(AwardStudentPoints::class)->handle(
            $this->student,
            ['points' => 5, 'reason' => 'competition', 'awarded_on' => '2026-09-02'],
            $this->admin,
        );

        $this->assertEqualsWithDelta(-3.0, (float) $penalty->points, 0.01);
        $this->assertSame($this->session->id, $penalty->attendance_session_id);

        $this->assertNull($standalone->attendance_session_id);
        $this->assertSame('2026-09-02', $standalone->awarded_on->toDateString());
    }

    public function test_a_locked_session_refuses_discretionary_points(): void
    {
        $this->session->update(['status' => SessionStatus::Locked]);

        $this->expectException(RuntimeException::class);

        app(AwardStudentPoints::class)->handle(
            $this->student,
            ['points' => 2, 'reason' => 'participation'],
            $this->admin,
            $this->session,
        );
    }

    public function test_the_total_gathers_every_source_inside_the_range(): void
    {
        $recitation = $this->save(1, 30);

        Attendance::factory()->create([
            'attendance_session_id' => $this->session->id,
            'student_id' => $this->student->id,
            'status' => AttendanceStatus::Present,
        ]);

        StudentPoint::factory()->create([
            'student_id' => $this->student->id,
            'points' => 4,
            'awarded_on' => '2026-09-01',
        ]);

        // خارج المدى — لا يُحتسب.
        StudentPoint::factory()->create([
            'student_id' => $this->student->id,
            'points' => 100,
            'awarded_on' => '2026-10-01',
        ]);

        $totals = app(CalculateStudentPoints::class)->handle($this->student, '2026-09-01', '2026-09-30');

        $this->assertEqualsWithDelta((float) $recitation->points, $totals['quran'], 0.01);
        $this->assertEqualsWithDelta(2.0, $totals['attendance'], 0.01);
        $this->assertEqualsWithDelta(4.0, $totals['manual'], 0.01);
        $this->assertSame(0.0, $totals['hadith']);
        $this->assertSame(0.0, $totals['mutun']);
        $this->assertEqualsWithDelta((float) $recitation->points + 6, $totals['total'], 0.01);
    }

    private function save(int $from, int $to, RecitationGrade $grade = RecitationGrade::Excellent): MemorizationLog
    {
        return app(SaveRecitation::class)->handle(
            $this->session->refresh(),
            $this->student,
            [
                'from_surah' => 67, 'from_ayah' => $from,
                'to_surah' => 67, 'to_ayah' => $to,
                'grade' => $grade->value, 'juz' => 29,
            ],
            $this->admin,
        );
    }
}
