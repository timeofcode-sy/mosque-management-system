<?php

namespace Tests\Feature\Api;

use App\Models\Announcement;
use App\Models\CustomField;
use App\Models\PersonalTrait;
use App\Models\Student;
use App\Models\Teacher;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * ما كان في اللوحة وحدها فصار في برنامج الإدارة: الأساتذةُ والإعلاناتُ والواصفاتُ والصفات —
 * بحرّاس اللوحة نفسِها وأفعالِها.
 */
class InstituteContentApiTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_an_admin_adds_edits_and_removes_a_teacher(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $uuid = $this->postJson('/api/v1/admin/teachers', [
            'display_name' => 'أحمد الشامي',
            'phone' => '0933000000',
            'status' => 'active',
        ])->assertCreated()->assertJsonPath('data.display_name', 'أحمد الشامي')->json('data.uuid');

        $teacher = Teacher::query()->where('uuid', $uuid)->sole();
        $this->assertSame($this->institute->id, $teacher->institute_id);

        $this->putJson("/api/v1/admin/teachers/{$uuid}", [
            'display_name' => 'أحمد الشامي',
            'specialization' => 'تجويد',
            'status' => 'active',
        ])->assertOk();

        $this->assertSame('تجويد', $teacher->refresh()->specialization);

        $this->deleteJson("/api/v1/admin/teachers/{$uuid}")->assertOk();
        $this->assertSoftDeleted($teacher);
    }

    public function test_a_supervisor_cannot_manage_teachers(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/admin/teachers', ['display_name' => 'x', 'status' => 'active'])->assertForbidden();
    }

    public function test_announcements_are_listed_written_and_withdrawn(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $uuid = $this->postJson('/api/v1/admin/announcements', [
            'title' => 'عطلة',
            'body' => 'لا دوام يوم الخميس.',
            'scope' => 'all',
            'audience' => ['students', 'guardians'],
        ])->assertCreated()->assertJsonPath('data.audience', ['students', 'guardians'])->json('data.uuid');

        $this->getJson('/api/v1/admin/announcements')->assertOk()->assertJsonPath('data.0.uuid', $uuid);

        $this->putJson("/api/v1/admin/announcements/{$uuid}", [
            'title' => 'عطلة رسمية',
            'body' => 'لا دوام يوم الخميس.',
            'scope' => 'all',
            'audience' => ['students'],
            'publish' => true,
        ])->assertOk()->assertJsonPath('data.title', 'عطلة رسمية');

        $this->postJson("/api/v1/admin/announcements/{$uuid}/unpublish")->assertOk()->assertJsonPath('data.published_at', null);
        $this->assertNull(Announcement::query()->where('uuid', $uuid)->value('published_at'));
    }

    public function test_custom_fields_and_traits_are_written_through_the_panel_actions(): void
    {
        $this->actingAsAdministrator($this->institute, 'admin');

        $field = $this->postJson('/api/v1/admin/custom-fields', [
            'entity' => 'student',
            'label' => 'فصيلة الدم',
            'type' => 'select',
            'options' => ['A+', 'O+'],
        ])->assertCreated()->json('data.uuid');

        $this->assertSame(['A+', 'O+'], CustomField::query()->where('uuid', $field)->value('options'));

        // العنوانُ يتغيّر والمفتاحُ يبقى: القيمُ المحفوظة معلَّقةٌ عليه.
        $key = CustomField::query()->where('uuid', $field)->value('key');
        $this->assertNotSame('', $key);
        $this->putJson("/api/v1/admin/custom-fields/{$field}", [
            'entity' => 'student',
            'label' => 'زمرة الدم',
            'type' => 'select',
            'options' => ['A+', 'O+', 'B+'],
        ])->assertOk();
        $this->assertSame($key, CustomField::query()->where('uuid', $field)->value('key'));

        $trait = $this->postJson('/api/v1/admin/traits', [
            'name' => 'مبادر',
            'polarity' => 'positive',
        ])->assertCreated()->json('data.uuid');

        // صفةٌ مسنَدةٌ إلى طالبٍ لا تُحذف، كما في اللوحة.
        $personalTrait = PersonalTrait::query()->where('uuid', $trait)->sole();
        Student::factory()->create(['institute_id' => $this->institute->id])->personalTraits()->attach($personalTrait->id, ['uuid' => (string) Str::uuid()]);

        $this->deleteJson("/api/v1/admin/traits/{$trait}")->assertUnprocessable();
        $this->deleteJson("/api/v1/admin/custom-fields/{$field}")->assertOk();
    }
}
