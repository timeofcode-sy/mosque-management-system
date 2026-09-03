<?php

namespace Database\Seeders;

use App\Enums\CurriculumType;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use Illuminate\Database\Seeder;

/**
 * المناهج العلمية ومحفوظاتها: القرآن الكريم (ثلاثون جزءاً)، الحديث الشريف، والمتون العلمية.
 * تُزرع كمناهج عامة (institute_id = null) ويمكن لكل معهد إضافة مناهجه الخاصة.
 */
class CurriculumSeeder extends Seeder
{
    /**
     * أسماء الأجزاء الثلاثين بالترتيب.
     *
     * @var array<int, string>
     */
    private const JUZ_NAMES = [
        'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن',
        'التاسع', 'العاشر', 'الحادي عشر', 'الثاني عشر', 'الثالث عشر', 'الرابع عشر',
        'الخامس عشر', 'السادس عشر', 'السابع عشر', 'الثامن عشر', 'التاسع عشر', 'العشرون',
        'الحادي والعشرون', 'الثاني والعشرون', 'الثالث والعشرون', 'الرابع والعشرون',
        'الخامس والعشرون', 'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون',
        'التاسع والعشرون', 'الثلاثون',
    ];

    /**
     * بنود الحديث وعدد أحاديث كلٍّ منها — العدد هو ما يضربه إعداد hadith_per_item.
     *
     * @var array<int, array{code: string, name: string, hadiths: int}>
     */
    private const HADITH_ITEMS = [
        ['code' => 'arbaeen-1', 'name' => 'الأربعون النبوية (1)', 'hadiths' => 42],
        ['code' => 'arbaeen-2', 'name' => 'الأربعون النبوية (2)', 'hadiths' => 40],
        ['code' => 'arbaeen-3', 'name' => 'الأربعون النبوية (3)', 'hadiths' => 40],
        ['code' => 'majami-anwar', 'name' => 'مجامع الأنوار', 'hadiths' => 60],
    ];

    /**
     * بنود المتون وعدد أبيات كلٍّ منها — العدد هو ما يضربه إعداد mutun_per_bayt.
     *
     * @var array<int, array{code: string, name: string, abyat: int}>
     */
    private const MUTUN_ITEMS = [
        ['code' => 'bayquniyyah', 'name' => 'المنظومة البيقونية', 'abyat' => 34],
        ['code' => 'lamiyyah', 'name' => 'اللامية', 'abyat' => 68],
        ['code' => 'tuhfat-al-atfal', 'name' => 'تحفة الأطفال', 'abyat' => 61],
        ['code' => 'aqidat-al-awam', 'name' => 'عقيدة العوام', 'abyat' => 57],
        ['code' => 'jazariyyah', 'name' => 'المقدمة الجزرية', 'abyat' => 107],
        ['code' => 'jawharat-al-tawhid', 'name' => 'جوهرة التوحيد', 'abyat' => 144],
        ['code' => 'urjuzah-miiyyah', 'name' => 'الأرجوزة الميئية', 'abyat' => 100],
    ];

    public function run(): void
    {
        $quran = $this->curriculum('quran', 'القرآن الكريم', CurriculumType::Quran, 0);

        foreach (self::JUZ_NAMES as $index => $juzName) {
            $juzNumber = $index + 1;

            $this->item($quran, "juz-{$juzNumber}", "الجزء {$juzName}", $index, ['juz' => $juzNumber]);
        }

        $hadith = $this->curriculum('hadith', 'الحديث الشريف', CurriculumType::Hadith, 1);

        foreach (self::HADITH_ITEMS as $index => $item) {
            $this->item($hadith, $item['code'], $item['name'], $index, ['hadiths' => $item['hadiths']]);
        }

        $mutun = $this->curriculum('mutun', 'المتون العلمية', CurriculumType::Mutun, 2);

        foreach (self::MUTUN_ITEMS as $index => $item) {
            $this->item($mutun, $item['code'], $item['name'], $index, ['abyat' => $item['abyat']]);
        }
    }

    private function curriculum(string $slug, string $name, CurriculumType $type, int $sortOrder): Curriculum
    {
        return Curriculum::query()->updateOrCreate(
            ['institute_id' => null, 'slug' => $slug],
            ['name' => $name, 'type' => $type, 'sort_order' => $sortOrder, 'is_active' => true],
        );
    }

    /**
     * @param  array<string, mixed>|null  $meta
     */
    private function item(Curriculum $curriculum, string $code, string $name, int $sortOrder, ?array $meta = null): CurriculumItem
    {
        return CurriculumItem::query()->updateOrCreate(
            ['curriculum_id' => $curriculum->id, 'code' => $code],
            ['name' => $name, 'sort_order' => $sortOrder, 'meta' => $meta, 'is_active' => true],
        );
    }
}
