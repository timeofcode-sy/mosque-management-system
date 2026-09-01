<?php

namespace Tests\Feature\Seeders;

use App\Enums\CurriculumType;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use Database\Seeders\CurriculumSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CurriculumSeederTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(CurriculumSeeder::class);
    }

    public function test_it_seeds_the_three_default_curricula(): void
    {
        $this->assertSame(3, Curriculum::query()->count());

        $this->assertSame(CurriculumType::Quran, Curriculum::query()->where('slug', 'quran')->sole()->type);
        $this->assertSame(CurriculumType::Hadith, Curriculum::query()->where('slug', 'hadith')->sole()->type);
        $this->assertSame(CurriculumType::Mutun, Curriculum::query()->where('slug', 'mutun')->sole()->type);
    }

    public function test_the_quran_curriculum_covers_the_thirty_parts(): void
    {
        $quran = Curriculum::query()->where('slug', 'quran')->sole();

        $this->assertCount(30, $quran->items);
        $this->assertSame('الجزء الأول', $quran->items->first()->name);
        $this->assertSame('الجزء الثلاثون', $quran->items->last()->name);
        $this->assertSame(1, $quran->items->first()->meta['juz']);
        $this->assertSame(30, $quran->items->last()->meta['juz']);
    }

    public function test_it_seeds_the_hadith_and_mutun_items_from_the_form(): void
    {
        $hadith = Curriculum::query()->where('slug', 'hadith')->sole();
        $mutun = Curriculum::query()->where('slug', 'mutun')->sole();

        $this->assertEqualsCanonicalizing(
            ['الأربعون النبوية (1)', 'الأربعون النبوية (2)', 'الأربعون النبوية (3)', 'مجامع الأنوار'],
            $hadith->items->pluck('name')->all(),
        );

        $this->assertEqualsCanonicalizing(
            [
                'المنظومة البيقونية', 'اللامية', 'تحفة الأطفال', 'عقيدة العوام',
                'المقدمة الجزرية', 'جوهرة التوحيد', 'الأرجوزة الميئية',
            ],
            $mutun->items->pluck('name')->all(),
        );
    }

    public function test_running_the_seeder_again_does_not_duplicate_items(): void
    {
        $this->seed(CurriculumSeeder::class);

        $this->assertSame(3, Curriculum::query()->count());
        $this->assertSame(41, CurriculumItem::query()->count());
    }
}
