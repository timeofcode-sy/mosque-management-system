<?php

namespace Tests\Feature\Api;

use App\Enums\TeacherRole;
use App\Models\AttendanceSession;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\Shift;
use App\Models\Student;
use App\Models\SyncDevice;
use App\Models\Teacher;
use App\Models\User;
use App\Support\InstituteTheme;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * ما أضافته المرحلة 5.1 إلى عقد الـ API: الأدوار في استجابة الدخول، وثيمُ المعهد في
 * اللقطة الأولى، وحصرُ فروع الدفع بمعهد صاحب التوكن، ومؤشّر آخر دفع.
 */
class Phase5ContractTest extends TestCase
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

    public function test_login_returns_the_users_roles(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);
        $user = User::factory()->create(['username' => 'teacher2395', 'password' => bcrypt('secret-pass')]);
        $teacher->update(['user_id' => $user->id]);
        $this->assignInstituteRole($user, $this->institute, 'teacher');

        // كانت تعود [] دائماً: المسار خارج institute.scope فمفتاح فريق spatie غير مضبوط.
        $this->postJson('/api/v1/auth/login', [
            'username' => 'teacher2395',
            'password' => 'secret-pass',
            'device_name' => 'هاتف الأستاذ',
        ])->assertOk()->assertJsonPath('user.roles', ['teacher']);
    }

    public function test_an_account_without_an_institute_still_logs_in_with_empty_roles(): void
    {
        User::factory()->create(['username' => 'admin9', 'password' => bcrypt('secret-pass')]);

        // التمييز مقصود: «كلمة مرور خاطئة» شيء و«حسابك غير مربوط بمعهد» شيء آخر —
        // والثاني يُكتشف عند أول نقطة بيانات لا عند الدخول.
        $this->postJson('/api/v1/auth/login', [
            'username' => 'admin9',
            'password' => 'secret-pass',
            'device_name' => 'حاسوب',
        ])->assertOk()->assertJsonPath('user.roles', []);
    }

    public function test_bootstrap_carries_the_role_the_theme_and_the_grace_period(): void
    {
        $this->institute->update(['settings' => [
            'theme' => ['primary' => '#7D0A0A', 'secondary' => '#FFBF9B', 'surface' => '#EAD196'],
            'attendance' => ['late_grace_minutes' => 7],
        ]]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create([
            'course_circle_id' => $this->courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('user.roles', ['teacher'])
            ->assertJsonPath('institute.theme.primary', '#7d0a0a')
            ->assertJsonPath('institute.theme.secondary', '#ffbf9b')
            ->assertJsonPath('institute.theme.surface', '#ead196')
            ->assertJsonPath('institute.attendance.late_grace_minutes', 7);
    }

    public function test_an_institute_without_colours_bootstraps_with_the_default_palette(): void
    {
        $this->actingAsTeacher($this->institute);

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('institute.theme.primary', InstituteTheme::DEFAULTS['primary']);
    }

    public function test_deleting_a_recitation_from_another_institute_is_refused(): void
    {
        $otherInstitute = Institute::factory()->create();
        $otherStudent = Student::factory()->create(['institute_id' => $otherInstitute->id]);
        $log = MemorizationLog::factory()->create(['student_id' => $otherStudent->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create([
            'course_circle_id' => $this->courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        // توكنٌ صالح + uuid من معهد آخر كان يمرّ: الفرع كان يستعمل firstOrFail() بلا حصر.
        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'recitation.delete',
                'recitation_uuid' => $log->uuid,
            ]],
        ])
            // 🔄 م.6.1: الرفض في failed[] لا في رمز الطلب — العمليةُ المرفوضة لم
            // تعد تُسقط الدفعة كلَّها معها، والحصرُ بالمعهد باقٍ كما هو.
            ->assertOk()
            ->assertJsonPath('applied', [])
            ->assertJsonCount(1, 'failed');

        $this->assertNotSoftDeleted($log);
    }

    public function test_completing_a_session_from_another_institute_is_refused(): void
    {
        $otherInstitute = Institute::factory()->create();
        $otherCourse = Course::factory()->current()->create(['institute_id' => $otherInstitute->id]);
        $otherShift = Shift::factory()->create(['course_id' => $otherCourse->id]);
        $otherCircle = CourseCircle::factory()->create(['course_id' => $otherCourse->id, 'shift_id' => $otherShift->id]);
        $otherSession = AttendanceSession::factory()->create(['course_circle_id' => $otherCircle->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create([
            'course_circle_id' => $this->courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.complete',
                'session_uuid' => $otherSession->uuid,
            ]],
        ])
            // 🔄 م.6.1: الرفض في failed[] لا في رمز الطلب — العمليةُ المرفوضة لم
            // تعد تُسقط الدفعة كلَّها معها، والحصرُ بالمعهد باقٍ كما هو.
            ->assertOk()
            ->assertJsonPath('applied', [])
            ->assertJsonCount(1, 'failed');
    }

    public function test_pushing_stamps_the_devices_last_push(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create([
            'course_circle_id' => $this->courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        $deviceUuid = (string) Str::uuid7();

        $this->postJson('/api/v1/devices/register', ['device_uuid' => $deviceUuid, 'app' => 'teacher'])->assertCreated();

        $this->postJson('/api/v1/sync/push', [
            'device_uuid' => $deviceUuid,
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-08',
            ]],
        ])->assertOk();

        // كان عموداً ميتاً تعرضه شاشة system/devices بـ«—» دائماً.
        $this->assertNotNull(SyncDevice::query()->where('device_uuid', $deviceUuid)->sole()->last_pushed_at);
    }
}
