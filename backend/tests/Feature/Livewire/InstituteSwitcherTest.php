<?php

namespace Tests\Feature\Livewire;

use App\Models\Institute;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use App\Support\PanelScope;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class InstituteSwitcherTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_a_global_role_switches_between_institutes(): void
    {
        $other = Institute::factory()->create();

        $superAdmin = User::factory()->create();
        $superAdmin->assignGlobalRole('super_admin');
        $this->actingAs($superAdmin);

        Livewire::test('institute-switcher')->call('switchTo', $other->uuid);

        $this->assertSame($other->id, session('institute_id'));
    }

    public function test_switching_to_an_institute_the_user_has_no_role_in_is_refused(): void
    {
        $other = Institute::factory()->create();

        $this->assertFalse(PanelScope::switchTo($other, $this->admin));
        $this->assertNotSame($other->id, session('institute_id'));
    }

    public function test_the_switcher_lists_only_the_institutes_the_user_belongs_to(): void
    {
        $other = Institute::factory()->create();
        $this->assignRole($this->admin, 'admin');

        $ids = PanelScope::institutesFor($this->admin)->modelKeys();

        $this->assertContains($this->institute->id, $ids);
        $this->assertNotContains($other->id, $ids);
    }

    /**
     * الثغرة التي سُدّت: السقوط إلى «أوّل معهد فعّال» كان يُدخل من لا معهد له إلى
     * معهدٍ لا صلة له به.
     */
    public function test_a_user_without_any_institute_gets_null_not_the_first_active_one(): void
    {
        $stranger = User::factory()->create();

        $this->assertNull(PanelScope::resolve($stranger));
    }

    public function test_a_global_role_still_falls_back_to_the_first_active_institute(): void
    {
        $developer = User::factory()->create();
        $developer->assignGlobalRole('developer');

        $this->assertSame($this->institute->id, PanelScope::resolve($developer)?->id);
    }

    /**
     * معهد الجلسة الذي لم يعد من حقّ المستخدم لا يُترك ليُعاد استعماله.
     */
    public function test_a_stale_session_institute_is_dropped(): void
    {
        $other = Institute::factory()->create();

        $teacher = User::factory()->create();
        Teacher::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $teacher->id]);

        session(['institute_id' => $other->id]);

        $this->assertSame($this->institute->id, PanelScope::resolve($teacher)?->id);
    }

    public function test_the_home_institute_comes_from_the_linked_record(): void
    {
        $student = User::factory()->create();
        Student::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $student->id]);

        $this->assertSame($this->institute->id, PanelScope::homeInstitute($student)?->id);
    }

    public function test_entering_an_institute_from_the_list_switches_the_context(): void
    {
        $other = Institute::factory()->create(['name' => 'معهد الفرقان']);

        $superAdmin = User::factory()->create();
        $superAdmin->assignGlobalRole('super_admin');
        $this->actingAs($superAdmin);

        Livewire::test('pages::institutes.index')->call('enter', $other->uuid);

        $this->assertSame($other->id, session('institute_id'));
    }
}
