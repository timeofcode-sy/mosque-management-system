<?php

namespace Tests\Feature\Actions;

use App\Actions\ChangeUserPassword;
use App\Enums\StudentStatus;
use App\Enums\TeacherStatus;
use App\Models\Guardian;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * التوليد الآلي لحسابات الأستاذ وولي الأمر والطالب — يقع في App\Observers مع
 * إنشاء السجلّ نفسه، فلا شاشةَ تُستدعى هنا.
 */
class GenerateAccountTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_every_record_kind_is_born_with_its_own_account(): void
    {
        $cases = [
            'student' => Student::factory()->create(['institute_id' => $this->institute->id]),
            'teacher' => Teacher::factory()->create(['institute_id' => $this->institute->id]),
            'guardian' => Guardian::factory()->create(['institute_id' => $this->institute->id]),
        ];

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);

        foreach ($cases as $role => $record) {
            $user = $record->fresh()->user;

            $this->assertNotNull($user, "لم يولَّد حساب لسجلّ {$role}.");
            $this->assertMatchesRegularExpression("/^{$role}\d{4,}$/", (string) $user->username);
            $this->assertTrue($user->hasRole($role));
            $this->assertTrue(Hash::check((string) $user->generated_password, $user->password));
        }
    }

    /**
     * التسلسل عام لا داخل المعهد: اسم المستخدم مفتاح الدخول وحده، ولو رُقّم داخل كل
     * معهد لتصادم طالبان من معهدين.
     */
    public function test_usernames_never_repeat_across_records(): void
    {
        Student::factory()->count(5)->create(['institute_id' => $this->institute->id]);

        $usernames = User::query()->whereNotNull('username')->pluck('username');

        $this->assertSame($usernames->count(), $usernames->unique()->count());
    }

    public function test_a_second_account_is_not_generated_for_a_linked_record(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $userId = $student->fresh()->user_id;

        $student->update(['first_name' => 'اسمٌ آخر']);

        $this->assertSame($userId, $student->fresh()->user_id);
        $this->assertSame(1, User::query()->where('username', 'like', 'student%')->count());
    }

    /**
     * الطالب المنسحب لا يدخل التطبيق، ورجوعُه يفتح حسابه بالاسم نفسه.
     */
    public function test_the_account_follows_the_record_status(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $student->update(['status' => StudentStatus::Withdrawn]);
        $this->assertFalse($student->fresh()->user->is_active);

        $student->update(['status' => StudentStatus::Active]);
        $this->assertTrue($student->fresh()->user->is_active);
    }

    public function test_a_teacher_who_left_loses_access(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);

        $teacher->update(['status' => TeacherStatus::Left]);

        $this->assertFalse($teacher->fresh()->user->is_active);
    }

    /**
     * الحذف اللين يُقفل الدخول ولا يحذف الحساب: سجلّات الحضور معلّقة به.
     */
    public function test_deleting_a_record_locks_its_account_without_deleting_it(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $userId = $student->user_id;

        $student->delete();

        $this->assertDatabaseHas('users', ['id' => $userId, 'is_active' => false]);
    }

    /**
     * كلمة الطالب تُدار من اللوحة وحدها — وتبقى مقروءةً بعد التبديل ليُعاد طبعُها.
     */
    public function test_a_supervisor_may_reissue_a_student_password(): void
    {
        $supervisor = User::factory()->create();
        $this->assignRole($supervisor, 'supervisor');

        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $password = app(ChangeUserPassword::class)->handle($supervisor, $student->fresh()->user);

        $this->assertMatchesRegularExpression('/^\d{8}$/', $password);
        $this->assertSame($password, $student->fresh()->user->generated_password);
        $this->assertTrue(Hash::check($password, $student->fresh()->user->password));
    }

    /**
     * الرتبة تحدّ الصلاحية: مشرفٌ لا يبلغ مشرفاً نظيره ولا مديرَ معهد.
     */
    public function test_a_supervisor_cannot_reach_a_peer_or_an_admin(): void
    {
        $supervisor = User::factory()->create();
        $this->assignRole($supervisor, 'supervisor');

        $peer = User::factory()->create();
        $this->assignRole($peer, 'supervisor');

        foreach ([$peer, $this->admin] as $target) {
            try {
                app(ChangeUserPassword::class)->handle($supervisor, $target);
                $this->fail('لم تُرفض محاولة تبديل كلمة مرور من هو في رتبته أو فوقها.');
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('لا تملك', $exception->getMessage());
            }
        }
    }

    /**
     * الطالب لا يبدّل كلمته بنفسه — وإلا بطلت النسخة المطبوعة بيد المشرف.
     */
    public function test_a_student_may_not_change_their_own_password(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $this->assertFalse($student->fresh()->user->managesOwnPassword());
        $this->assertTrue($this->admin->managesOwnPassword());
    }
}
