<?php

namespace Tests\Feature\Api;

use App\Enums\CurriculumType;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\Institute;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use Database\Seeders\CurriculumSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * المناهجُ وبنودُها في الـ API — ✅ م.6.5.
 *
 * وهي **الفجوةُ المسمّاة** في [CHECKPOINT-PHASE-6.2.MD §10] البند 4 و
 * [APPS-FEATURES.md §4.2] البند 5ج: `SaveCurriculumItem` قائمٌ منذ م.4.5
 * ولا غلافَ له، فكان بابُ المناهج في الديسكتوب يحتاج متصفّحاً.
 */
class CurriculumApiTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->seed(CurriculumSeeder::class);
        $this->buildInstitute();
    }

    public function test_an_admin_creates_a_curriculum_and_adds_items_to_it(): void
    {
        $this->actingAsAdministrator($this->institute);

        $uuid = $this->postJson('/api/v1/admin/curricula', [
            'name' => 'الأربعون النووية',
            'type' => 'hadith',
        ])->assertCreated()->json('data.uuid');

        $item = $this->postJson("/api/v1/admin/curricula/{$uuid}/items", [
            'name' => 'الحديث الأول',
            'count' => 1,
        ])->assertCreated();

        // العدّاد يتبع نوعَ المنهج — الأحاديث للحديث لا مفتاحٌ عامّ (م.4.5).
        $item->assertJsonPath('data.meta.hadiths', 1);

        // والرمزُ يُشتقّ من الترتيب حين يُترك فارغاً، فلا يفشل الحفظ بقيدٍ لا
        // يعرف صاحبُ الشاشة أنه موجود.
        $this->assertSame('item-1', $item->json('data.code'));

        $this->assertDatabaseHas('curricula', [
            'uuid' => $uuid,
            'institute_id' => $this->institute->id,
            'slug' => 'alarbaaon-alnooy',
        ]);
    }

    public function test_the_thirty_juz_are_fixed_neither_added_to_nor_deleted(): void
    {
        $this->actingAsAdministrator($this->institute);

        $quran = Curriculum::query()->where('slug', 'quran')->sole();
        $juz = $quran->items()->orderBy('sort_order')->first();

        $this->postJson("/api/v1/admin/curricula/{$quran->uuid}/items", ['name' => 'الجزء الحادي والثلاثون'])
            ->assertStatus(422);

        $this->deleteJson("/api/v1/admin/curriculum-items/{$juz->uuid}")->assertStatus(422);

        // وتحريرُ اسم جزءٍ قائم مسموح — الثابتُ عددُها لا أسماؤها.
        $this->putJson("/api/v1/admin/curriculum-items/{$juz->uuid}", ['name' => 'جزء عمّ'])
            ->assertOk()
            ->assertJsonPath('data.name', 'جزء عمّ');

        $this->assertSame(30, $quran->items()->count());
    }

    /**
     * 🔴 عطبٌ كشفته م.6.5: منهجٌ عامّ يُحرَّر من معهدٍ فيصير ملكَه — ويختفي عن
     * بقية المعاهد بلا خطأ يُرمى.
     */
    public function test_a_seeded_global_curriculum_cannot_be_taken_over_by_an_institute(): void
    {
        $this->actingAsAdministrator($this->institute);

        $quran = Curriculum::query()->where('slug', 'quran')->sole();

        $this->putJson("/api/v1/admin/curricula/{$quran->uuid}", [
            'name' => 'القرآن — نسختي',
            'type' => 'quran',
        ])->assertStatus(422);

        $this->assertNull($quran->refresh()->institute_id);
        $this->assertSame('القرآن الكريم', $quran->name);
    }

    public function test_an_item_bound_to_recorded_progress_is_not_deleted(): void
    {
        $this->actingAsAdministrator($this->institute);

        $curriculum = Curriculum::factory()->create([
            'institute_id' => $this->institute->id,
            'type' => CurriculumType::Mutun,
        ]);
        $item = CurriculumItem::factory()->create(['curriculum_id' => $curriculum->id]);

        StudentCurriculumProgress::factory()->create([
            'student_id' => Student::factory()->create(['institute_id' => $this->institute->id])->id,
            'curriculum_item_id' => $item->id,
        ]);

        $this->deleteJson("/api/v1/admin/curriculum-items/{$item->uuid}")->assertStatus(422);

        $this->assertModelExists($item);
    }

    public function test_the_institute_boundary_is_not_crossed(): void
    {
        $this->actingAsAdministrator($this->institute);

        $other = Institute::factory()->create();
        $foreign = Curriculum::factory()->create(['institute_id' => $other->id]);

        $this->putJson("/api/v1/admin/curricula/{$foreign->uuid}", [
            'name' => 'منهج مسروق',
            'type' => 'custom',
        ])->assertNotFound();

        $this->postJson("/api/v1/admin/curricula/{$foreign->uuid}/items", ['name' => 'بند'])
            ->assertNotFound();
    }

    public function test_a_teacher_does_not_reach_the_curriculum_endpoints(): void
    {
        $this->actingAsTeacher($this->institute);

        $this->postJson('/api/v1/admin/curricula', ['name' => 'منهج', 'type' => 'custom'])
            ->assertForbidden();
    }
}
