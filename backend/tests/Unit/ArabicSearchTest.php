<?php

namespace Tests\Unit;

use App\Support\ArabicSearch;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class ArabicSearchTest extends TestCase
{
    public function test_similar_letters_and_marks_are_folded(): void
    {
        $this->assertSame('احمد', ArabicSearch::normalize('أحمد'));
        $this->assertSame('احمد', ArabicSearch::normalize('أَحْـمَد'));
        $this->assertSame('عايشه', ArabicSearch::normalize('عائشة'));
        $this->assertSame('مصطفي', ArabicSearch::normalize('مصطفى'));
        $this->assertSame('عبدالرحمن الزغلول', ArabicSearch::normalize('عبد الرحمن  الزغلول'));
        $this->assertSame('0944', ArabicSearch::normalize('٠٩٤٤'));
    }

    /**
     * @return array<string, array{string, list<string>, bool}>
     */
    public static function queries(): array
    {
        return [
            'hamza forms' => ['احمد', ['أحمد', 'محمد', 'الزغلول'], true],
            'two words, any order' => ['الزغلول جابر', ['جابر', 'فواز', 'الزغلول'], true],
            'no definite article' => ['زغلول', ['جابر', 'فواز', 'الزغلول'], true],
            'start of a word' => ['الزغ', ['جابر', 'فواز', 'الزغلول'], true],
            'compound name' => ['عبدالرحمن', ['عبد الرحمن', 'فواز', 'الزغلول'], true],
            'part of a phone' => ['4994', ['جابر', '0944994123'], true],
            // قريبٌ بالإملاء ليس تطابقاً: يأتي في «أقرب النتائج» وحدها (درجةٌ فوق الصفر).
            'one letter off' => ['الزغلوم', ['جابر', 'فواز', 'الزغلول'], false],
            'unrelated' => ['يوسف', ['جابر', 'فواز', 'الزغلول'], false],
        ];
    }

    /**
     * @param  list<string>  $fields
     */
    #[DataProvider('queries')]
    public function test_a_query_matches_the_fields_it_should(string $query, array $fields, bool $expected): void
    {
        $this->assertSame($expected, ArabicSearch::match($query, $fields)['complete']);
    }

    public function test_the_closer_match_scores_higher(): void
    {
        $exact = ArabicSearch::match('محمد', ['محمد', 'سامر'])['score'];
        $prefix = ArabicSearch::match('محمد', ['محمدنور', 'سامر'])['score'];
        $near = ArabicSearch::match('محمود', ['محمد', 'سامر'])['score'];

        $this->assertGreaterThan($prefix, $exact);
        $this->assertGreaterThan($near, $prefix);
        $this->assertGreaterThan(0, $near);
    }

    public function test_the_edit_distance_counts_letters_not_bytes(): void
    {
        $this->assertSame(1, ArabicSearch::distance('محمد', 'محمود'));
        $this->assertSame(0, ArabicSearch::distance('أنس', 'أنس'));
    }
}
