<?php

namespace Tests\Feature\Livewire;

use App\Enums\CourseStatus;
use App\Models\Institute;
use App\Models\SyncConflict;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Spatie\Permission\PermissionRegistrar;
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
            ->assertSet('issuedCredentials', fn (?array $issued) => is_array($issued)
                && preg_match('/^supervisor\d{4,}$/', (string) $issued['username']) === 1
                && preg_match('/^\d{8}$/', $issued['password']) === 1);

        $this->assertDatabaseHas('users', ['email' => 'zaid@mousqe.test']);
    }

    /**
     * قائمة الإنشاء لا تعرض إلا الأدوار الإدارية — لا «طالب» ولا «أستاذ».
     */
    public function test_the_creation_form_offers_administrative_roles_only(): void
    {
        Livewire::test('pages::users.index')
            ->call('invite')
            ->set('first_name', 'زيد')
            ->set('last_name', 'الأنصاري')
            ->set('new_role', 'student')
            ->set('new_institute', (string) $this->institute->id)
            ->call('save')
            ->assertHasErrors('new_role');
    }

    /**
     * إقفال الحساب يمنع دخوله؛ ولا يُقفل أحدٌ حسابه هو.
     */
    public function test_an_account_can_be_locked_from_the_users_screen(): void
    {
        $target = User::factory()->create();
        $this->assignRole($target, 'supervisor');

        Livewire::test('pages::users.index')->call('toggleActivation', $target->id, false);

        $this->assertFalse($target->fresh()->is_active);

        /** الفاعل هنا هو المبرمج نفسه — ولا يُقفل أحدٌ حسابه */
        Livewire::test('pages::users.index')->call('toggleActivation', $this->developer->id, false);

        $this->assertTrue($this->developer->fresh()->is_active);
    }

    /**
     * سجلّ الأستاذ يخرج ومعه حسابُه — لا زرّ ولا خطوةَ إنشاء.
     */
    public function test_a_teacher_record_is_born_with_a_login_account(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);

        $user = $teacher->fresh()->user;

        $this->assertNotNull($user);
        $this->assertMatchesRegularExpression('/^teacher\d{4,}$/', (string) $user->username);
        $this->assertMatchesRegularExpression('/^\d{8}$/', (string) $user->generated_password);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $this->assertTrue($user->hasRole('teacher'));
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
