<?php

namespace Tests\Feature\Api;

use App\Models\Institute;
use App\Support\ApiScope;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * البند الأول في المرحلة 6: طريقُ مديرِ المعهد والمشرف إلى الـ API.
 *
 * كان `ApiScope` يحسم المعهد من سجلّ teacher/guardian/student وحده، وحساباتُ الأربعة
 * الذين يخدمهم الديسكتوب تُنشأ بلا أيٍّ منها عمداً ⇒ 422 على كل نقطة. فلم يكن يدخل
 * الـ API مشرفٌ إلا إن كان **أيضاً** أستاذاً مسجَّلاً — [CLIENTS.md §5 البند 2].
 */
class DesktopScopeTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_an_institute_admin_without_a_linked_record_reaches_the_api(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('institute.uuid', $this->institute->uuid)
            ->assertJsonPath('user.roles', ['admin'])
            ->assertJsonPath('user.teacher_uuid', null);
    }

    public function test_a_supervisor_reaches_the_api_and_carries_the_permissions_that_set_them_apart(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $response = $this->getJson('/api/v1/bootstrap')->assertOk();
        $permissions = $response->json('user.permissions');

        // ما يميّز الديسكتوب عن تطبيق الأستاذ: تعديلُ تفقّدٍ بعد الإقفال، وقفلُ الجلسة.
        $this->assertContains('attendance.amend', $permissions);
        $this->assertContains('attendance.lock', $permissions);
        $this->assertContains('conflicts.review', $permissions);
    }

    public function test_bootstrap_gives_a_supervisor_every_circle_in_the_current_course(): void
    {
        $first = $this->makeCourseCircle('حلقة الفجر');
        $second = $this->makeCourseCircle('حلقة العصر');

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $uuids = collect($this->getJson('/api/v1/bootstrap')->assertOk()->json('circles'))->pluck('uuid')->all();

        $this->assertContains($first->uuid, $uuids);
        $this->assertContains($second->uuid, $uuids);
    }

    public function test_a_guardian_still_gets_no_circles(): void
    {
        // توسيعُ /bootstrap للديسكتوب لا يفتح حلقاتِ المعهد لمن لا يملك circles.view.
        $this->makeCourseCircle();
        $this->actingAsGuardian();

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('circles', []);
    }

    public function test_an_admin_can_push_and_pull_like_any_client(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $this->getJson('/api/v1/sync/pull?since=0&app=admin_desktop')->assertOk();
    }

    public function test_a_developer_without_any_institute_falls_back_to_the_first_active_one(): void
    {
        $this->actingAsGlobalRole('developer');

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('institute.uuid', $this->institute->uuid);
    }

    public function test_a_developer_switches_institutes_with_the_header(): void
    {
        $other = Institute::factory()->create(['name' => 'معهد ثانٍ']);
        $this->actingAsGlobalRole('developer');

        $this->withHeader(ApiScope::HEADER, $other->uuid)
            ->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('institute.uuid', $other->uuid);
    }

    public function test_an_admin_cannot_switch_into_an_institute_they_do_not_work_in(): void
    {
        $other = Institute::factory()->create();
        $this->actingAsAdministrator($this->institute, 'admin');

        // الرفضُ صريح لا تجاهلٌ صامت: لو سقط الطلب إلى المعهد الأصلي بلا خبر لَكتب
        // مديرُ المعهد بيانات وهو يظنّها في معهدٍ آخر.
        $this->withHeader(ApiScope::HEADER, $other->uuid)
            ->getJson('/api/v1/bootstrap')
            ->assertForbidden();
    }

    public function test_the_institutes_endpoint_lists_only_what_the_account_may_work_in(): void
    {
        $other = Institute::factory()->create();
        $this->actingAsAdministrator($this->institute, 'admin');

        $response = $this->getJson('/api/v1/institutes')->assertOk();

        $this->assertSame($this->institute->uuid, $response->json('current'));

        $uuids = collect($response->json('data'))->pluck('uuid')->all();
        $this->assertContains($this->institute->uuid, $uuids);
        $this->assertNotContains($other->uuid, $uuids);
    }

    public function test_the_institutes_endpoint_shows_every_institute_to_a_developer(): void
    {
        $other = Institute::factory()->create();
        $this->actingAsGlobalRole('developer');

        $uuids = collect($this->getJson('/api/v1/institutes')->assertOk()->json('data'))->pluck('uuid')->all();

        $this->assertContains($this->institute->uuid, $uuids);
        $this->assertContains($other->uuid, $uuids);
    }

    public function test_an_account_with_no_institute_at_all_is_still_refused(): void
    {
        // القاعدة الباقية: لا تخمين. حسابٌ بلا سجلٍّ ولا دورٍ في معهد يبقى 422.
        $this->actingAsOrphan();

        $this->getJson('/api/v1/bootstrap')->assertStatus(422);
    }
}
