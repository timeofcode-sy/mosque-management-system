<?php

namespace Tests\Feature\Api;

use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\TeacherAttendance;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * سلطةُ الجلسة في الطابور — ✅ م.6.4.
 *
 * وهي ما يميّز الديسكتوب من تطبيق الأستاذ ([APPS-FEATURES.md §4.2] البندان 2 و3):
 * الأستاذُ يفتح الجلسة ويتفقّد ويُكملها كلَّ يوم، **والمشرفُ وحده** يقفلها نهائياً
 * ويتفقّد الأساتذة أنفسَهم.
 *
 * وكلاهما كان مكسوراً حتى هذه المرحلة: `LockAttendanceSession` بلا نوعٍ في الطابور
 * أصلاً — يُستدعى من اللوحة وحدها — و`attendance.teacher.take` بنوعٍ بلا حارس، فكان
 * الأستاذُ يستطيع أن يتفقّد نفسَه لو عرف اسم النوع.
 */
class SessionAuthorityTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle('حلقة الفرقان');

        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $this->student->id,
        ]);
    }

    public function test_a_supervisor_completes_and_locks_a_session_in_one_offline_batch(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        // الترتيبُ هو العقد: القفلُ لا يقع إلا على مكتملة، والإكمالُ يسبقه في نفس
        // الدفعة — فالمشرف يقفل جلسةَ يومٍ من مكتبه بضغطةٍ واحدة وهو أوف-لاين.
        $this->postJson('/api/v1/sync/push', ['operations' => [
            $this->op('attendance.session.open'),
            $this->op('attendance.session.complete'),
            $this->op('attendance.session.lock'),
        ]])
            ->assertOk()
            ->assertJsonPath('failed', []);

        $this->assertSame(
            SessionStatus::Locked,
            AttendanceSession::firstOrFail()->status,
        );
    }

    public function test_locking_a_session_needs_the_permission_the_teacher_does_not_hold(): void
    {
        $this->actingAsTeacher($this->institute);

        $this->postJson('/api/v1/sync/push', ['operations' => [
            $this->op('attendance.session.open'),
            $this->op('attendance.session.complete'),
        ]])->assertOk()->assertJsonPath('failed', []);

        // الإكمالُ مرّ — وهو ما يفعله الأستاذُ كلَّ يوم — والقفلُ وحده رُدّ.
        $lock = $this->op('attendance.session.lock');

        $this->postJson('/api/v1/sync/push', ['operations' => [$lock]])
            ->assertOk()
            ->assertJsonPath('failed.0.op_uuid', $lock['op_uuid']);

        $this->assertSame(
            SessionStatus::Completed,
            AttendanceSession::firstOrFail()->status,
        );
    }

    public function test_a_draft_session_is_not_locked_and_says_why(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $lock = $this->op('attendance.session.lock');

        // حكمُ الفعل نفسِه لا حكمُ الوسيط: `LockAttendanceSession` يرفض غيرَ
        // المكتملة، فتُعزل العمليةُ برسالتها العربية بدل أن تُقفل مسوّدةً.
        $this->postJson('/api/v1/sync/push', ['operations' => [
            $this->op('attendance.session.open'),
            $lock,
        ]])
            ->assertOk()
            ->assertJsonPath('failed.0.op_uuid', $lock['op_uuid'])
            ->assertJsonPath('failed.0.message', 'لا تُقفل إلا الجلسة المكتملة.');

        $this->assertSame(
            SessionStatus::Draft,
            AttendanceSession::firstOrFail()->status,
        );
    }

    public function test_a_teacher_cannot_record_teacher_attendance_from_their_own_app(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);

        $take = fn (): array => $this->op('attendance.teacher.take', [
            'teacher_attendances' => [
                ['teacher_uuid' => $teacher->uuid, 'status' => 'present'],
            ],
        ]);

        $rejected = $take();

        $this->postJson('/api/v1/sync/push', ['operations' => [
            $this->op('attendance.session.open'),
            $rejected,
        ]])
            ->assertOk()
            ->assertJsonPath('failed.0.op_uuid', $rejected['op_uuid']);

        $this->assertDatabaseCount('teacher_attendances', 0);

        // والمشرفُ يمرّ — `teachers.view` هي ما يفصل الجمهورين، والجلسةُ نفسُها.
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/sync/push', ['operations' => [$take()]])
            ->assertOk()
            ->assertJsonPath('failed', []);

        $this->assertSame(
            $teacher->id,
            TeacherAttendance::firstOrFail()->teacher_id,
        );
    }

    public function test_teacher_attendance_never_crosses_the_institute_boundary(): void
    {
        $foreign = Teacher::factory()->create();

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/sync/push', ['operations' => [
            $this->op('attendance.session.open'),
            $this->op('attendance.teacher.take', [
                'teacher_attendances' => [
                    ['teacher_uuid' => $foreign->uuid, 'status' => 'present'],
                ],
            ]),
        ]])->assertOk()->assertJsonPath('failed', []);

        // أستاذٌ من معهدٍ آخر يُتخطّى صفُّه بلا كتابةٍ ولا رفضِ الدفعة — نظير الطالب
        // المجهول في `attendance.take`.
        $this->assertDatabaseCount('teacher_attendances', 0);
    }

    /**
     * @param  array<string, mixed>  $extra
     * @return array<string, mixed>
     */
    private function op(string $type, array $extra = []): array
    {
        return [
            'op_uuid' => (string) Str::uuid7(),
            'type' => $type,
            'course_circle_uuid' => $this->courseCircle->uuid,
            'session_date' => '2026-09-09',
            ...$extra,
        ];
    }
}
