<?php

namespace Tests\Feature\Api;

use App\Enums\CourseStatus;
use App\Models\Circle;
use App\Models\Course;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\User;
use App\Support\ApiScope;
use App\Support\InstituteTheme;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * سطحُ الإدارة في الـ API — البند الثالث في [APPS-FEATURES.md §4.4]، ونطاقُ م.6.2.
 *
 * كان أكبرَ ما يحجب الديسكتوب: المعاهدُ والمستخدمون والأدوارُ وبياناتُ الدخول وبنيةُ
 * الدورة تُكتب من اللوحة مباشرةً بلا نقطةٍ واحدة في `/api/v1` ([CLIENTS.md §2]).
 *
 * وكلُّها REST مباشر لا أنواعَ عملياتٍ في الطابور، بقاعدة [PHASE-6-STAGES.MD §3.1]:
 * من يُنشئ حساباً ينتظر كلمةَ المرور ليطبعها، ولا معنى لطابورٍ يحمل سرّاً إلى وقتٍ
 * لاحق.
 */
class AdminSurfaceTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_an_institute_admin_creates_a_supervisor_and_receives_the_generated_password_once(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $response = $this->postJson('/api/v1/admin/users', [
            'first_name' => 'خالد',
            'last_name' => 'المصري',
            'role' => 'supervisor',
        ])->assertCreated();

        $password = $response->json('credentials.password');
        $username = $response->json('credentials.username');

        $this->assertNotEmpty($password);
        $this->assertStringStartsWith('supervisor', (string) $username);

        // الحساب يعمل فعلاً بالكلمة المعروضة — وإلا كانت البطاقة المطبوعة ورقةً بلا معنى.
        $this->postJson('/api/v1/auth/login', [
            'username' => $username,
            'password' => $password,
            'device_name' => 'ديسكتوب المشرف',
        ])->assertOk();
    }

    public function test_nobody_assigns_a_role_above_their_own_through_the_api(): void
    {
        // نفسُ حراسة AssignUserRole::assertAssignable على اللوحة: إخفاءُ الخيار من
        // القائمة ليس حماية، والطلبُ يصل الخادم كيفما بُنيت الواجهة.
        $this->actingAsAdministrator($this->institute, 'admin');

        $this->postJson('/api/v1/admin/users', [
            'first_name' => 'مبرمج',
            'last_name' => 'متسلّل',
            'role' => 'developer',
        ])->assertStatus(422);
    }

    public function test_a_supervisor_cannot_reach_the_accounts_surface_at_all(): void
    {
        // الفرقُ بين المشرف ومديرِ المعهد صلاحياتٌ لا نسخةُ برنامج: المشرف يبلغ
        // البطاقاتِ ولا يبلغ إنشاءَ الحسابات ولا بنيةَ الدورة.
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->getJson('/api/v1/admin/users')->assertForbidden();
        $this->postJson('/api/v1/admin/courses', ['name' => 'دورة', 'starts_on' => '2026-01-01', 'status' => 'draft'])->assertForbidden();
        $this->putJson('/api/v1/admin/institute', ['name' => 'محاولة'])->assertForbidden();

        $this->getJson('/api/v1/admin/credentials')->assertOk();
    }

    public function test_the_role_catalog_comes_from_the_server_not_from_a_copy_in_dart(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $response = $this->getJson('/api/v1/admin/roles')->assertOk();

        $creatable = collect($response->json('creatable'))->pluck('name')->all();

        $this->assertSame(['admin', 'supervisor'], $creatable);
        $this->assertNotContains('teacher', $creatable, 'حساباتُ الأستاذ يولّدها النظام مع سجلّه.');
        $this->assertSame('مدير معهد', $response->json('creatable.0.label'));
    }

    public function test_an_admin_edits_their_institute_colours_and_the_untouched_settings_survive(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $response = $this->putJson('/api/v1/admin/institute', [
            'name' => 'معهد النور',
            'theme' => ['primary' => '#7d0a0a', 'secondary' => '#ffbf9b', 'surface' => '#ead196'],
        ])->assertOk();

        $this->assertSame('#7d0a0a', $response->json('data.theme.primary'));

        // إعداداتُ النقاط لم تُرسل، فبقيت كما كانت — الحمولةُ الجزئية لا تمسح ما قبلها.
        $this->assertNotEmpty($response->json('data.points'));

        $this->institute->refresh();
        $this->assertSame('#7d0a0a', InstituteTheme::for($this->institute)->toArray()['primary']);
        $this->assertSame('معهد النور', $this->institute->name);
    }

    public function test_creating_an_institute_is_withheld_from_an_institute_admin_and_open_to_a_developer(): void
    {
        // institutes.manage منزوعةٌ من admin عمداً — [APPS-FEATURES.md §4.3].
        $this->actingAsAdministrator($this->institute, 'admin');
        $this->postJson('/api/v1/admin/institutes', ['name' => 'معهد ثانٍ'])->assertForbidden();

        $this->actingAsGlobalRole('developer');

        $uuid = $this->postJson('/api/v1/admin/institutes', [
            'name' => 'معهد الفرقان',
        ])->assertCreated()->json('data.uuid');

        $institute = Institute::query()->where('uuid', $uuid)->firstOrFail();

        // ومعه دورةٌ أولى مسودّة، وإلا استقبل صاحبَه بستّ شاشات تقول «لا دورة جارية».
        $this->assertDatabaseHas('courses', ['institute_id' => $institute->id, 'status' => CourseStatus::Draft->value]);
    }

    public function test_an_admin_builds_the_course_structure_over_the_api(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $courseUuid = $this->postJson('/api/v1/admin/courses', [
            'name' => 'دورة 1448',
            'starts_on' => '2026-10-01',
            'ends_on' => '2026-12-31',
            'status' => 'draft',
        ])->assertCreated()->json('data.uuid');

        $shiftUuid = $this->postJson('/api/v1/admin/shifts', [
            'course_uuid' => $courseUuid,
            'name' => 'الدوام الصباحي',
            'starts_at' => '08:00',
            'ends_at' => '11:00',
            'weekdays' => [0, 2, 4],
        ])->assertCreated()->json('data.uuid');

        $this->assertSame([0, 2, 4], Shift::query()->where('uuid', $shiftUuid)->firstOrFail()
            ->days()->pluck('weekday')->map(fn ($day): int => (int) $day)->sort()->values()->all());

        $circleUuid = $this->postJson('/api/v1/admin/circles', [
            'name' => 'حلقة الفرقان',
            'level' => 'متوسط',
        ])->assertCreated()->json('data.uuid');

        $this->postJson("/api/v1/admin/circles/{$circleUuid}/run", [
            'course_uuid' => $courseUuid,
            'shift_uuid' => $shiftUuid,
            'room' => 'قاعة 2',
            'capacity' => 15,
        ])->assertCreated()->assertJsonPath('data.circle_name', 'حلقة الفرقان');

        // الحلقةُ تعمل مرّةً واحدة في الدورة — قيدُ الهجرة يُفحص فتعود رسالةٌ مقروءة.
        $this->postJson("/api/v1/admin/circles/{$circleUuid}/run", [
            'course_uuid' => $courseUuid,
            'shift_uuid' => $shiftUuid,
        ])->assertStatus(422);

        $this->assertDatabaseHas('circles', ['uuid' => $circleUuid, 'institute_id' => $this->institute->id]);
        $this->assertDatabaseHas('courses', ['uuid' => $courseUuid, 'institute_id' => $this->institute->id]);
    }

    public function test_catalog_writes_never_cross_the_institute_boundary(): void
    {
        $other = Institute::factory()->create();
        $foreign = Circle::factory()->create(['institute_id' => $other->id]);
        $foreignCourse = Course::factory()->create(['institute_id' => $other->id]);

        $this->actingAsAdministrator($this->institute, 'admin');

        $this->putJson("/api/v1/admin/circles/{$foreign->uuid}", ['name' => 'اختطاف'])->assertNotFound();
        $this->putJson("/api/v1/admin/courses/{$foreignCourse->uuid}", [
            'name' => 'اختطاف', 'starts_on' => '2026-01-01', 'status' => 'draft',
        ])->assertNotFound();
    }

    public function test_credentials_and_activation_stay_inside_the_rank_ladder(): void
    {
        $peer = User::factory()->create();
        $this->assignInstituteRole($peer, $this->institute, 'admin');

        $actor = $this->actingAsAdministrator($this->institute, 'admin');

        // نظيرٌ في الرتبة: لا تُبدَّل كلمتُه ولا يُقفل حسابُه — ChangeUserPassword/outranks.
        $this->postJson("/api/v1/admin/users/{$peer->id}/password")->assertStatus(422);
        $this->postJson("/api/v1/admin/users/{$peer->id}/activation", ['is_active' => false])->assertStatus(422);

        $below = User::factory()->create();
        $this->assignInstituteRole($below, $this->institute, 'supervisor');
        ApiScope::for($actor)->institute();

        $password = $this->postJson("/api/v1/admin/users/{$below->id}/password")
            ->assertOk()
            ->json('credentials.password');

        $this->assertSame(8, strlen((string) $password));

        $this->postJson("/api/v1/admin/users/{$below->id}/activation", ['is_active' => false])
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $this->assertFalse((bool) $below->refresh()->is_active);
    }

    public function test_the_users_list_carries_every_role_assignment_with_its_institute(): void
    {
        $target = User::factory()->create(['first_name' => 'سعيد', 'last_name' => 'الحلبي']);
        $this->assignInstituteRole($target, $this->institute, 'supervisor');

        $this->actingAsAdministrator($this->institute, 'admin');

        $response = $this->getJson('/api/v1/admin/users?q=سعيد')->assertOk();

        // بالمعرّف لا بالموضع: البذرةُ تولّد أسماءً عربية قد يقع فيها نفسُ الجذر.
        $row = collect($response->json('data'))->firstWhere('id', $target->id);

        $this->assertNotNull($row);
        $this->assertSame('سعيد الحلبي', $row['name']);
        $this->assertSame('supervisor', $row['roles'][0]['role']);
        $this->assertSame('مشرف', $row['roles'][0]['label']);
        $this->assertSame($this->institute->name, $row['roles'][0]['institute']);

        // ⚠️ لا كلمةَ مرور في هذه القائمة: النسخةُ المقروءة من نقطة البطاقات وحدها.
        $this->assertArrayNotHasKey('password', $row);
    }
}
