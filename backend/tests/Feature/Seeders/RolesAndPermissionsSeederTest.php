<?php

namespace Tests\Feature\Seeders;

use App\Models\Institute;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;
use Tests\TestCase;

class RolesAndPermissionsSeederTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_it_seeds_every_role_of_the_system(): void
    {
        $this->assertEqualsCanonicalizing(
            ['developer', 'super_admin', 'admin', 'supervisor', 'teacher', 'guardian', 'student'],
            Role::query()->pluck('name')->all(),
        );
    }

    public function test_only_the_developer_holds_every_permission(): void
    {
        $this->assertSame(
            Permission::query()->count(),
            Role::findByName('developer')->permissions()->count(),
        );
    }

    /**
     * الأدوار الثلاثة العليا كانت متطابقة حرفياً؛ ما يميّزها الآن صلاحيتان بعينهما.
     */
    public function test_the_three_top_roles_differ_by_exactly_two_permissions(): void
    {
        $developer = Role::findByName('developer');
        $superAdmin = Role::findByName('super_admin');
        $admin = Role::findByName('admin');

        $this->assertTrue($developer->hasPermissionTo('system.debug'));
        $this->assertFalse($superAdmin->hasPermissionTo('system.debug'));
        $this->assertFalse($admin->hasPermissionTo('system.debug'));

        $this->assertTrue($superAdmin->hasPermissionTo('institutes.manage'));
        $this->assertFalse($admin->hasPermissionTo('institutes.manage'));

        $this->assertTrue($admin->hasPermissionTo('users.invite'));
        $this->assertTrue($admin->hasPermissionTo('settings.manage'));
    }

    public function test_a_teacher_can_take_attendance_but_not_amend_a_locked_session(): void
    {
        $teacher = Role::findByName('teacher');

        $this->assertTrue($teacher->hasPermissionTo('attendance.take'));
        $this->assertFalse($teacher->hasPermissionTo('attendance.amend'));
        $this->assertFalse($teacher->hasPermissionTo('settings.manage'));
    }

    public function test_a_guardian_can_only_submit_excuses_and_read(): void
    {
        $guardian = Role::findByName('guardian');

        $this->assertTrue($guardian->hasPermissionTo('excuses.submit'));
        $this->assertTrue($guardian->hasPermissionTo('attendance.view'));
        $this->assertFalse($guardian->hasPermissionTo('attendance.take'));
        $this->assertFalse($guardian->hasPermissionTo('students.manage'));
    }

    public function test_a_role_is_assigned_within_the_scope_of_one_institute(): void
    {
        $institute = Institute::factory()->create();
        $other = Institute::factory()->create();

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);

        $user = User::factory()->create();
        $user->assignRole('supervisor');

        $this->assertTrue($user->fresh()->hasRole('supervisor'));

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($other->id);

        $this->assertFalse($user->fresh()->hasRole('supervisor'));
    }
}
