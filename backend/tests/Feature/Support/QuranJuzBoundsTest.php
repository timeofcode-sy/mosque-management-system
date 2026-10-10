<?php

namespace Tests\Feature\Support;

use App\Support\Quran;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class QuranJuzBoundsTest extends TestCase
{
    /**
     * @return array<string, array{int, array{int, int, int, int}}>
     */
    public static function bounds(): array
    {
        return [
            'الجزء الأول' => [1, [1, 1, 2, 141]],
            'الجزء الثاني' => [2, [2, 142, 2, 252]],
            'الجزء الحادي عشر' => [11, [9, 93, 11, 5]],
            'الجزء الثالث عشر يختم إبراهيم' => [13, [12, 53, 14, 52]],
            'جزء عمّ' => [30, [78, 1, 114, 6]],
        ];
    }

    /**
     * @param  array{int, int, int, int}  $expected
     */
    #[DataProvider('bounds')]
    public function test_a_juz_runs_from_its_first_ayah_to_the_one_before_the_next_juz(int $juz, array $expected): void
    {
        $this->assertSame($expected, Quran::juzBounds($juz));
    }

    public function test_the_thirty_juz_cover_the_mushaf_exactly_once(): void
    {
        $this->assertSame(Quran::TOTAL_AYAHS, array_sum(array_map(Quran::juzAyahs(...), range(1, 30))));
        $this->assertSame(148, Quran::juzAyahs(1));
    }

    public function test_every_juz_agrees_with_its_surah_list(): void
    {
        foreach (range(1, 30) as $juz) {
            $this->assertSame(Quran::surahsOfJuz($juz), array_keys(Quran::juzSegments($juz)), "الجزء {$juz}");
        }
    }

    public function test_an_ayah_falls_in_the_juz_whose_bounds_hold_it(): void
    {
        $this->assertSame(1, Quran::juzOf(2, 141));
        $this->assertSame(2, Quran::juzOf(2, 142));
        $this->assertSame(30, Quran::juzOf(114, 6));
        $this->assertSame('الفاتحة 1 ← البقرة 141', Quran::juzLabel(1));
    }
}
