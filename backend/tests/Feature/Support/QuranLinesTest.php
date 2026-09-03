<?php

namespace Tests\Feature\Support;

use App\Support\Quran;
use Tests\TestCase;

class QuranLinesTest extends TestCase
{
    public function test_the_line_table_covers_every_surah_of_the_mushaf(): void
    {
        $this->assertCount(114, Quran::LINES);
        $this->assertSame(array_keys(Quran::SURAHS), array_keys(Quran::LINES));

        foreach (Quran::LINES as $surah => $lines) {
            $this->assertGreaterThan(0, $lines, "السورة {$surah} بلا أسطر.");
        }
    }

    public function test_the_lines_add_up_to_the_madinah_mushaf(): void
    {
        // 604 صفحة × 15 سطراً = 9060، والجدول تقديريّ فيُقبل انحراف طفيف.
        $this->assertEqualsWithDelta(9060, array_sum(Quran::LINES), 120);
    }

    public function test_a_partial_range_takes_its_share_of_the_surah_lines(): void
    {
        // الملك ثلاثون آية في 31 سطراً؛ الآيات 13–30 ثمانيَ عشرة آية.
        $this->assertEqualsWithDelta(31.0, Quran::linesForRange(67, 1, 67, 30), 0.01);
        $this->assertEqualsWithDelta(18 / 30 * 31, Quran::linesForRange(67, 13, 67, 30), 0.01);
    }

    public function test_a_range_across_two_surahs_sums_both_shares(): void
    {
        $expected = Quran::linesForRange(112, 1, 112, 4) + Quran::linesForRange(113, 1, 113, 5);

        $this->assertEqualsWithDelta($expected, Quran::linesForRange(112, 1, 113, 5), 0.01);
    }

    public function test_every_juz_lists_its_surahs(): void
    {
        $this->assertCount(30, Quran::JUZ_SURAHS);
        $this->assertSame([1, 2], Quran::surahsOfJuz(1));
        $this->assertContains(67, Quran::surahsOfJuz(29));
        $this->assertSame(78, Quran::surahsOfJuz(30)[0]);
        $this->assertSame(114, Quran::surahsOfJuz(30)[count(Quran::surahsOfJuz(30)) - 1]);

        // كل سورة تظهر في جزء واحد على الأقل، والممتدّة تظهر في كل جزء تمرّ به.
        $covered = collect(Quran::JUZ_SURAHS)->flatten()->unique()->sort()->values()->all();

        $this->assertSame(range(1, 114), $covered);
    }
}
