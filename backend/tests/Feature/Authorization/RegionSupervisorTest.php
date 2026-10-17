<?php

namespace Tests\Feature\Authorization;

use App\Actions\AssignUserRole;
use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use App\Support\PanelScope;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Livewire\Livewire;
use RuntimeException;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * «مشرف معاهد»: يشرف على معاهد محدّدة — مثل «مشرف معاهد عربين» على عمر الفاروق والنور والسلام —
 * فيعمل فيها كلِّها ويقارن بينها، ولا يرى غيرها ولا ينشئ معهداً.
 */
class RegionSupervisorTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Institute $nour;

    private Institute $salam;

    private Institute $elsewhere;

    private User $regional;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->institute->update(['name' => 'معهد عمر الفاروق']);

        $this->nour = Institute::factory()->create(['name' => 'معهد النور']);
        $this->salam = Institute::factory()->create(['name' => 'معهد السلام']);
        $this->elsewhere = Institute::factory()->create(['name' => 'معهد بعيد']);

        $this->regional = User::factory()->create();

        foreach ([$this->institute, $this->nour, $this->salam] as $institute) {
            $this->assignIn($this->regional, 'region_supervisor', $institute);
        }
    }

    public function test_the_role_sits_between_the_super_admin_and_the_institute_admin(): void
    {
        $this->assertFalse(PanelRole::RegionSupervisor->isGlobal());
        $this->assertTrue(PanelRole::RegionSupervisor->isAdministrative());
        $this->assertGreaterThan(PanelRole::SuperAdmin->rank(), PanelRole::RegionSupervisor->rank());
        $this->assertLessThan(PanelRole::Admin->rank(), PanelRole::RegionSupervisor->rank());
        $this->assertSame('مشرف معاهد', PanelRole::RegionSupervisor->label());
    }

    public function test_it_may_compare_institutes_but_not_create_them(): void
    {
        $role = Role::findByName('region_supervisor');

        $this->assertTrue($role->hasPermissionTo('institutes.overview'));
        $this->assertFalse($role->hasPermissionTo('institutes.manage'));
        $this->assertFalse($role->hasPermissionTo('system.debug'));
        $this->assertFalse(Role::findByName('admin')->hasPermissionTo('institutes.overview'));
    }

    public function test_it_works_in_its_institutes_and_nowhere_else(): void
    {
        $ids = PanelScope::institutesFor($this->regional)->modelKeys();

        $this->assertEqualsCanonicalizing([$this->institute->id, $this->nour->id, $this->salam->id], $ids);
        $this->assertTrue(PanelScope::switchTo($this->nour, $this->regional));
        $this->assertFalse(PanelScope::switchTo($this->elsewhere, $this->regional));
    }

    public function test_the_institutes_overview_shows_only_its_institutes(): void
    {
        $this->actingAs($this->regional);

        $this->get(route('institutes.overview'))
            ->assertOk()
            ->assertSee('معهد عمر الفاروق')
            ->assertSee('معهد النور')
            ->assertSee('معهد السلام')
            ->assertDontSee('معهد بعيد')
            ->assertDontSee('إدارة المعاهد');

        $this->get(route('institutes.index'))->assertForbidden();
    }

    public function test_the_institute_admin_cannot_open_the_overview(): void
    {
        $this->get(route('institutes.overview'))->assertForbidden();
    }

    public function test_a_super_admin_assigns_it_across_several_institutes_at_once(): void
    {
        $superAdmin = User::factory()->create();
        $superAdmin->assignGlobalRole('super_admin');
        $this->actingAs($superAdmin);

        $target = User::factory()->create();

        Livewire::test('pages::users.index')
            ->call('openRoleForm', $target->id)
            ->set('new_role', 'region_supervisor')
            ->set('new_institutes', [(string) $this->nour->id, (string) $this->salam->id])
            ->call('assign')
            ->assertHasNoErrors();

        $this->assertEqualsCanonicalizing([$this->nour->id, $this->salam->id], $target->fresh()->roleInstituteIds());
        $this->assertSame(['region_supervisor'], $target->fresh()->allRoleNames());
    }

    public function test_choosing_no_institute_for_it_is_refused(): void
    {
        $superAdmin = User::factory()->create();
        $superAdmin->assignGlobalRole('super_admin');
        $this->actingAs($superAdmin);

        Livewire::test('pages::users.index')
            ->call('openRoleForm', User::factory()->create()->id)
            ->set('new_role', 'region_supervisor')
            ->call('assign')
            ->assertHasErrors('new_institutes');
    }

    public function test_it_appoints_an_institute_admin_in_its_institutes_only(): void
    {
        $this->actingAs($this->regional);
        $target = User::factory()->create();

        Livewire::test('pages::users.index')
            ->call('openRoleForm', $target->id)
            ->set('new_role', 'admin')
            ->set('new_institute', (string) $this->elsewhere->id)
            ->call('assign')
            ->assertHasErrors('new_institute');

        Livewire::test('pages::users.index')
            ->call('openRoleForm', $target->id)
            ->set('new_role', 'admin')
            ->set('new_institute', (string) $this->nour->id)
            ->call('assign')
            ->assertHasNoErrors();

        $this->assertSame([$this->nour->id], $target->fresh()->roleInstituteIds());
    }

    public function test_an_institute_admin_cannot_appoint_one(): void
    {
        $this->expectException(RuntimeException::class);

        AssignUserRole::assertAssignable($this->admin, PanelRole::RegionSupervisor);
    }

    /**
     * «كل المعاهد» في شاشة المستخدمين كانت تعني كلَّها لكل من يفتحها، فيرى مديرُ
     * معهدٍ حساباتِ معاهد لا يعمل فيها.
     */
    public function test_the_users_list_hides_accounts_of_institutes_it_does_not_supervise(): void
    {
        $outsider = User::factory()->create(['first_name' => 'غريب']);
        $this->assignIn($outsider, 'admin', $this->elsewhere);

        $insider = User::factory()->create(['first_name' => 'قريب']);
        $this->assignIn($insider, 'admin', $this->salam);

        $this->actingAs($this->regional);

        Livewire::test('pages::users.index')
            ->assertSee('قريب')
            ->assertDontSee('غريب');
    }

    private function assignIn(User $user, string $role, Institute $institute): void
    {
        $registrar = App::make(PermissionRegistrar::class);
        $previous = $registrar->getPermissionsTeamId();
        $registrar->setPermissionsTeamId($institute->id);
        $user->assignRole($role);
        $registrar->setPermissionsTeamId($previous);
        $user->unsetRelation('roles');
    }
}
