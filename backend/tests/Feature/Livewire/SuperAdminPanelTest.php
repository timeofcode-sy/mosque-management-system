<?php

namespace Tests\Feature\Livewire;

use App\Enums\CourseStatus;
use App\Models\Institute;
use App\Models\SyncConflict;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * شاشات الإدارة العليا وأدوات المبرمج — التصيير والأفعال.
 */
class SuperAdminPanelTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private User $developer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();

        $this->developer = User::factory()->create();
        $this->developer->assignGlobalRole('developer');
        $this->actingAs($this->developer);
    }

    public function test_every_super_admin_screen_renders(): void
    {
        foreach ([
            route('institutes.index'),
            route('institutes.create'),
            route('institutes.edit', $this->institute),
            route('institutes.overview'),
            route('users.index'),
            route('system.conflicts'),
            route('system.devices'),
            route('system.change-log'),
        ] as $url) {
            $this->get($url)->assertOk();
        }
    }

    /**
     * المعهد الجديد يُبذر معه دورة أولى: بدونها تستقبل كلُّ شاشة تشغيلية صاحبَه
     * بتنبيه «لا توجد دورة جارية».
     */
    public function test_creating_an_institute_seeds_a_draft_course(): void
    {
        Livewire::test('pages::institutes.form')
            ->set('name', 'معهد الفرقان')
            ->set('short_name', 'الفرقان')
            ->call('save')
            ->assertHasNoErrors();

        $institute = Institute::query()->where('name', 'معهد الفرقان')->firstOrFail();

        $this->assertSame(1, $institute->courses()->count());
        $this->assertSame(CourseStatus::Draft, $institute->courses()->first()->status);
    }

    public function test_an_institute_can_be_deactivated_and_reactivated(): void
    {
        $other = Institute::factory()->create();

        Livewire::test('pages::institutes.index')->call('toggleActive', $other->uuid);
        $this->assertFalse($other->fresh()->is_active);

        Livewire::test('pages::institutes.index')->call('toggleActive', $other->uuid);
        $this->assertTrue($other->fresh()->is_active);
    }

    /**
     * حذف المعهد الذي تعمل فيه الآن يسحب البساط من تحت الجلسة نفسها.
     */
    public function test_the_current_institute_cannot_be_deleted(): void
    {
        $this->withSession(['institute_id' => $this->institute->id]);

        Livewire::test('pages::institutes.index')->call('delete', $this->institute->uuid);

        $this->assertNotSoftDeleted($this->institute);
    }

    public function test_a_user_can_be_invited_with_a_role_from_the_users_screen(): void
    {
        Livewire::test('pages::users.index')
            ->call('invite')
            ->set('first_name', 'زيد')
            ->set('last_name', 'الأنصاري')
            ->set('email', 'zaid@mousqe.test')
            ->set('new_role', 'supervisor')
            ->set('new_institute', (string) $this->institute->id)
            ->call('save')
            ->assertHasNoErrors()
            ->assertSet('inviteLink', fn (?string $link) => is_string($link) && $link !== '');

        $this->assertDatabaseHas('users', ['email' => 'zaid@mousqe.test']);
    }

    /**
     * زرّ «إنشاء حساب دخول» في شاشة الأساتذة — شرط تشغيل تطبيق الأستاذ.
     */
    public function test_a_teacher_record_gains_a_login_account(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::teachers.index')
            ->call('createAccount', $teacher->uuid)
            ->set('account_email', 'ustaz@mousqe.test')
            ->call('saveAccount')
            ->assertHasNoErrors();

        $this->assertNotNull($teacher->fresh()->user_id);
        $this->assertDatabaseHas('users', ['email' => 'ustaz@mousqe.test']);
    }

    public function test_a_sync_conflict_can_be_marked_reviewed(): void
    {
        $conflict = SyncConflict::create([
            'table_name' => 'attendances',
            'row_uuid' => (string) Str::uuid7(),
            'server_payload' => ['status' => 'present'],
            'client_payload' => ['status' => 'absent'],
            'resolution' => 'server_wins',
        ]);

        Livewire::test('pages::system.sync-conflicts')->call('markReviewed', $conflict->uuid);

        $this->assertNotNull($conflict->fresh()->resolved_at);
        $this->assertSame($this->developer->id, $conflict->fresh()->reviewed_by);
    }
}
