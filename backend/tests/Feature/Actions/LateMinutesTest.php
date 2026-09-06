<?php

namespace Tests\Feature\Actions;

use App\Actions\OpenAttendanceSession;
use App\Actions\TakeAttendance;
use App\Actions\TakeTeacherAttendance;
use App\Enums\AttendanceStatus;
use App\Enums\TeacherRole;
use App\Models\Attendance;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\Teacher;
use App\Support\LateMinutes;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * دقائق التأخير تُحسب على الخادم من بداية الدوام — فيستوي مصدرُ الكتابة: لوحةٌ أو
 * تطبيقٌ أو دفعةُ مزامنة تعطي الرقم نفسه لنفس الحدث.
 */
class LateMinutesTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

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
            'enrolled_on' => '2026-09-01',
        ]);
    }

    public function test_late_minutes_are_computed_from_the_shift_start_when_none_are_sent(): void
    {
        // الدوام يبدأ 08:00 (ShiftFactory) والطالب سُجّل 08:17 ⇒ سبع عشرة دقيقة.
        $attendance = $this->take(recordedAt: '2026-09-08 08:17:00');

        $this->assertSame(17, $attendance->late_minutes);
    }

    public function test_a_value_sent_explicitly_wins_over_the_computed_one(): void
    {
        // الحالة قرار الأستاذ والرقم تلقائي، لكن تصحيحه اليدوي يبقى مسموحاً.
        $attendance = $this->take(recordedAt: '2026-09-08 08:17:00', lateMinutes: 5);

        $this->assertSame(5, $attendance->late_minutes);
    }

    public function test_arriving_before_the_shift_starts_is_zero_not_negative(): void
    {
        $attendance = $this->take(recordedAt: '2026-09-08 07:40:00');

        $this->assertSame(0, $attendance->late_minutes);
    }

    public function test_the_grace_period_is_subtracted(): void
    {
        $this->institute->update(['settings' => ['attendance' => ['late_grace_minutes' => 10]]]);

        $attendance = $this->take(recordedAt: '2026-09-08 08:17:00');

        $this->assertSame(7, $attendance->late_minutes);
    }

    public function test_a_backdated_take_records_no_phantom_lateness(): void
    {
        // تفقّدٌ رجعي: الجلسة ليوم مضى والتسجيل اليوم. الفرق أيامٌ لا دقائق، ورقمٌ
        // بحجم آلاف الدقائق أسوأ من لا رقم.
        Carbon::setTestNow('2026-09-10 20:00:00');

        $attendance = $this->take(sessionDate: '2026-09-08', recordedAt: null);

        Carbon::setTestNow();

        $this->assertSame(0, $attendance->late_minutes);
    }

    public function test_a_status_other_than_late_never_carries_minutes(): void
    {
        $attendance = $this->take(status: AttendanceStatus::Present, recordedAt: '2026-09-08 08:17:00');

        $this->assertNull($attendance->late_minutes);
    }

    public function test_a_session_with_no_shift_behind_it_yields_no_reference(): void
    {
        // shifts.starts_at غير قابل لأن يكون فارغاً في المخطّط، فالحالة الوحيدة الباقية
        // هي جلسةٌ فقدت حلقتها — والحارس هنا يمنع تحوّل بياناتٍ ناقصة إلى رقمٍ مخترَع.
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-08', $this->admin);
        $session->setRelation('courseCircle', null);

        $this->assertNull(LateMinutes::forSession($session, Carbon::parse('2026-09-08 09:00:00')));
    }

    public function test_teacher_lateness_uses_the_same_reference(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);
        CourseCircleTeacher::create([
            'course_circle_id' => $this->courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        Carbon::setTestNow('2026-09-08 08:25:00');

        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-08', $this->admin);

        app(TakeTeacherAttendance::class)->handle(
            $session,
            [$teacher->id => ['status' => AttendanceStatus::Late->value]],
            $this->admin,
        );

        Carbon::setTestNow();

        $this->assertSame(25, $session->teacherAttendances()->sole()->late_minutes);
    }

    private function take(
        AttendanceStatus $status = AttendanceStatus::Late,
        string $sessionDate = '2026-09-08',
        ?string $recordedAt = '2026-09-08 08:17:00',
        ?int $lateMinutes = null,
    ): Attendance {
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, $sessionDate, $this->admin);

        app(TakeAttendance::class)->handle(
            $session,
            [$this->student->id => array_filter([
                'status' => $status->value,
                'late_minutes' => $lateMinutes,
                'recorded_at' => $recordedAt,
            ], fn ($value) => $value !== null)],
            $this->admin,
        );

        return $session->attendances()->where('student_id', $this->student->id)->sole();
    }
}
