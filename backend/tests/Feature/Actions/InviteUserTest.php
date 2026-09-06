<?php

namespace Tests\Feature\Actions;

use App\Actions\AssignUserRole;
use App\Actions\InviteUser;
use App\Actions\RevokeUserRole;
use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class InviteUserTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_it_assigns_the_role_inside_the_chosen_institute_only(): void
    {
        $other = Institute::factory()->create();

        $result = $this->invite(PanelRole::Supervisor, $this->institute);
        $user = $result['user']->fresh();

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $this->assertTrue($user->hasRole('supervisor'));

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($other->id);
        $this->assertFalse($user->fresh()->hasRole('supervisor'));
    }

    /**
     * لا قناة بريد في المشروع، فالتسليم هو نسخُ الاسم والكلمة من الشاشة.
     */
    public function test_it_returns_login_credentials_that_actually_work(): void
    {
        $result = $this->invite(PanelRole::Supervisor, $this->institute);

        $this->assertMatchesRegularExpression('/^supervisor\d{4,}$/', (string) $result['user']->username);
        $this->assertMatchesRegularExpression('/^\d{8}$/', $result['password']);
        $this->assertTrue(Hash::check($result['password'], $result['user']->password));
    }

    /**
     * النسخة المشفَّرة هي ما يُعاد طبعُه بعد أن يُغلق حوار الإنشاء.
     */
    public function test_the_generated_password_stays_readable_for_reprinting(): void
    {
        $result = $this->invite(PanelRole::Supervisor, $this->institute);

        $this->assertSame($result['password'], $result['user']->fresh()->generated_password);
    }

    /**
     * البريد صار اختيارياً: الطالب وولي الأمر لا بريد لهما، فلم يعد شرطاً للحساب.
     */
    public function test_an_account_needs_no_email(): void
    {
        $result = app(InviteUser::class)->handle(
            $this->admin,
            ['first_name' => 'بلا', 'last_name' => 'بريد'],
            PanelRole::Supervisor,
            $this->institute,
        );

        $this->assertNull($result['user']->email);
        $this->assertNotNull($result['user']->username);
    }

    /**
     * الأدوار الثلاثة المولَّدة لا تُنشأ يدوياً — حسابٌ بلا سجلّ يرفضه ApiScope
     * بـ 422 فلا يفتح تطبيقاً أصلاً.
     */
    public function test_generated_roles_cannot_be_created_by_hand(): void
    {
        foreach ([PanelRole::Teacher, PanelRole::Guardian, PanelRole::Student] as $role) {
            try {
                $this->invite($role, $this->institute);
                $this->fail("لم يُرفض إنشاء حساب {$role->value} يدوياً.");
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('يولّدها النظام', $exception->getMessage());
            }
        }
    }

    /**
     * مدير المعهد يرى «مدير معهد» و«مشرف» لا غير في قائمة الإنشاء.
     */
    public function test_an_admin_may_only_create_admins_and_supervisors(): void
    {
        $names = array_map(fn (PanelRole $role) => $role->value, AssignUserRole::creatableRoles($this->admin));

        $this->assertSame(['admin', 'supervisor'], $names);
    }

    public function test_a_super_admin_may_also_create_super_admins(): void
    {
        $superAdmin = User::factory()->create();
        $superAdmin->assignGlobalRole('super_admin');

        $names = array_map(fn (PanelRole $role) => $role->value, AssignUserRole::creatableRoles($superAdmin));

        $this->assertSame(['super_admin', 'admin', 'supervisor'], $names);
    }

    public function test_an_admin_cannot_grant_a_role_above_his_own(): void
    {
        foreach ([PanelRole::SuperAdmin, PanelRole::Developer] as $role) {
            try {
                $this->invite($role, null);
                $this->fail("لم يُرفض إسناد الدور {$role->value}.");
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('لا تملك صلاحية', $exception->getMessage());
            }
        }
    }

    /**
     * الدور العابر يُسنَد خارج كل معهد؛ عليه يقوم Gate::before وحده.
     */
    public function test_a_global_role_is_assigned_outside_every_institute(): void
    {
        $developer = User::factory()->create();
        $developer->assignGlobalRole('developer');

        $result = app(InviteUser::class)->handle(
            $developer,
            ['first_name' => 'مشرف', 'last_name' => 'أعلى'],
            PanelRole::SuperAdmin,
        );

        $this->assertTrue($result['user']->fresh()->hasGlobalRole('super_admin'));
        $this->assertTrue($result['user']->fresh()->can('institutes.manage'));
    }

    public function test_revoking_follows_the_same_hierarchy_guard(): void
    {
        $target = User::factory()->create();
        $target->assignGlobalRole('super_admin');

        $this->expectException(RuntimeException::class);

        app(RevokeUserRole::class)->handle($this->admin, $target, PanelRole::SuperAdmin);
    }

    /**
     * @return array{user: User, password: string}
     */
    private function invite(PanelRole $role, ?Institute $institute): array
    {
        return app(InviteUser::class)->handle(
            $this->admin,
            ['first_name' => 'حساب', 'last_name' => 'جديد'],
            $role,
            $institute,
        );
    }
}
