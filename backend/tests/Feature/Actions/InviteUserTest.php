<?php

namespace Tests\Feature\Actions;

use App\Actions\AssignUserRole;
use App\Actions\InviteUser;
use App\Actions\RevokeUserRole;
use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
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

        $result = $this->invite('teacher@mousqe.test', PanelRole::Teacher, $this->institute);
        $user = $result['user']->fresh();

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $this->assertTrue($user->hasRole('teacher'));

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($other->id);
        $this->assertFalse($user->fresh()->hasRole('teacher'));
    }

    public function test_it_creates_and_links_the_teacher_record(): void
    {
        $result = $this->invite('new-teacher@mousqe.test', PanelRole::Teacher, $this->institute);

        $teacher = Teacher::query()->where('user_id', $result['user']->id)->first();

        $this->assertNotNull($teacher);
        $this->assertSame($this->institute->id, $teacher->institute_id);
    }

    /**
     * الربط بسجلّ قائم هو ما يفعله زرّ «إنشاء حساب دخول» في شاشة الأساتذة — وبدونه
     * يرفض ApiScope الحسابَ بـ 422 فلا يفتح تطبيق الأستاذ.
     */
    public function test_it_links_an_existing_teacher_record_instead_of_creating_one(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);

        $result = $this->invite('linked@mousqe.test', PanelRole::Teacher, $this->institute, $teacher);

        $this->assertSame($result['user']->id, $teacher->fresh()->user_id);
        $this->assertSame(1, Teacher::query()->where('institute_id', $this->institute->id)->count());
    }

    public function test_it_returns_a_password_reset_link_since_there_is_no_mail_channel(): void
    {
        $result = $this->invite('link@mousqe.test', PanelRole::Teacher, $this->institute);

        $this->assertStringStartsWith(url('reset-password'), $result['reset_url']);
        $this->assertStringContainsString('email=link%40mousqe.test', $result['reset_url']);
    }

    public function test_an_admin_cannot_grant_a_role_above_his_own(): void
    {
        foreach ([PanelRole::SuperAdmin, PanelRole::Developer] as $role) {
            try {
                $this->invite("above-{$role->value}@mousqe.test", $role, null);
                $this->fail("لم يُرفض إسناد الدور {$role->value}.");
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('لا تملك صلاحية', $exception->getMessage());
            }
        }
    }

    public function test_a_super_admin_may_grant_super_admin_but_not_developer(): void
    {
        $superAdmin = User::factory()->create();
        $superAdmin->assignGlobalRole('super_admin');

        $names = array_map(fn (PanelRole $role) => $role->value, AssignUserRole::assignableRoles($superAdmin));

        $this->assertContains('super_admin', $names);
        $this->assertNotContains('developer', $names);
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
            ['first_name' => 'مشرف', 'last_name' => 'أعلى', 'email' => 'sa@mousqe.test'],
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
     * @return array{user: User, reset_url: string}
     */
    private function invite(string $email, PanelRole $role, ?Institute $institute, ?Teacher $record = null): array
    {
        return app(InviteUser::class)->handle(
            $this->admin,
            ['first_name' => 'حساب', 'last_name' => 'جديد', 'email' => $email],
            $role,
            $institute,
            $record,
        );
    }
}
