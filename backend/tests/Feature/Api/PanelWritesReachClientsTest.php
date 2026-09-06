<?php

namespace Tests\Feature\Api;

use App\Actions\OpenAttendanceSession;
use App\Actions\ReviewAbsenceExcuse;
use App\Actions\SaveStudentRegistration;
use App\Actions\TakeAttendance;
use App\Enums\AttendanceStatus;
use App\Enums\ExcuseStatus;
use App\Enums\GuardianRelation;
use App\Enums\TeacherRole;
use App\Models\AbsenceExcuse;
use App\Models\ChangeLog;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Student;
use App\Models\User;
use App\Support\SyncRecorder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * الفجوة الحاجبة للمرحلة 5: كتابات اللوحة كانت لا تدخل change_log إطلاقاً، فطالبٌ
 * يُسجَّل أو تفقّدٌ يُعدَّل من اللوحة لا يصل تطبيق الأستاذ أبداً. صار التسجيلُ أثراً
 * بنيوياً لكل نموذج ينفّذ App\Contracts\Syncable.
 */
class PanelWritesReachClientsTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle();
    }

    public function test_a_student_registered_from_the_panel_appears_in_the_teachers_pull(): void
    {
        $student = app(SaveStudentRegistration::class)->handle($this->institute, [
            'first_name' => 'محمد',
            'father_name' => 'خالد',
            'family_name' => 'المصري',
            'gender' => 'male',
        ]);

        $rowUuids = $this->pullRowUuids();

        $this->assertContains($student->uuid, $rowUuids);
    }

    public function test_attendance_edited_from_the_panel_reaches_the_client_row_by_row(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $student->id,
            'enrolled_on' => '2026-09-01',
        ]);

        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-08', $this->admin);

        app(TakeAttendance::class)->handle(
            $session,
            [$student->id => ['status' => AttendanceStatus::Absent->value]],
            $this->admin,
        );

        $attendance = $session->attendances()->where('student_id', $student->id)->sole();

        $change = ChangeLog::query()
            ->where('table_name', 'attendances')
            ->where('row_uuid', $attendance->uuid)
            ->latest('id')
            ->firstOrFail();

        // الحمولة هي صفُّ الحضور نفسه لا صفُّ الجلسة: بلا هذا يعرف العميل أن شيئاً
        // تغيّر ولا يعرف ماذا.
        $this->assertSame(AttendanceStatus::Absent->value, $change->payload['status']);
        $this->assertNull($change->device_uuid);
        $this->assertContains($attendance->uuid, $this->pullRowUuids());
    }

    public function test_an_excuse_reviewed_from_the_panel_reaches_the_client(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $excuse = AbsenceExcuse::factory()->create(['student_id' => $student->id, 'status' => ExcuseStatus::Pending]);

        app(ReviewAbsenceExcuse::class)->handle($excuse, ExcuseStatus::Approved, $this->admin);

        $this->assertContains($excuse->uuid, $this->pullRowUuids());
    }

    public function test_an_excuse_submitted_over_rest_by_a_guardian_reaches_the_client(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $guardian = Guardian::factory()->create(['institute_id' => $this->institute->id]);
        $guardianUser = User::factory()->create();
        $guardian->update(['user_id' => $guardianUser->id]);

        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $student->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
            'can_view_reports' => true,
            'can_submit_excuses' => true,
        ]);

        $this->assignInstituteRole($guardianUser, $this->institute, 'guardian');
        Sanctum::actingAs($guardianUser, ['*']);

        // الكتابة الوحيدة في النظام عبر REST مباشر لا عبر sync/push — وكانت لا تُسجَّل.
        $this->postJson('/api/v1/guardian/excuses', [
            'student_uuid' => $student->uuid,
            'from_date' => '2026-09-08',
            'to_date' => '2026-09-09',
            'reason' => 'سفر عائلي',
        ])->assertCreated();

        $excuse = AbsenceExcuse::query()->where('student_id', $student->id)->sole();

        $this->assertContains($excuse->uuid, $this->pullRowUuids());
    }

    public function test_seeding_does_not_flood_the_change_log(): void
    {
        // قاعدةٌ تُبنى من الصفر ليست تغييراً يُبثّ، وجهازٌ جديد يسحب من since=0 يراها كاملةً.
        $before = ChangeLog::query()->count();

        app(SyncRecorder::class)->without(fn () => Student::factory()->create(['institute_id' => $this->institute->id]));

        $this->assertSame($before, ChangeLog::query()->count());
    }

    /**
     * @return array<int, string>
     */
    private function pullRowUuids(): array
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create([
            'course_circle_id' => $this->courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        $response = $this->getJson('/api/v1/sync/pull?since=0&app=teacher');
        $response->assertOk();

        return collect($response->json('changes'))->pluck('row_uuid')->all();
    }
}
