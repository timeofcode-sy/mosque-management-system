<?php

namespace App\Support;

use Illuminate\Contracts\Database\Eloquent\Builder;

/**
 * بحثٌ عربيّ متسامح: «احمد» يجد «أحمد»، و«عبدالرحمن» يجد «عبد الرحمن»، و«الزغلو» يجد «الزغلول»،
 * و«محمود» يجد «محمد» إن لم يوجد غيره — ويُرتَّب الأقربُ أولاً.
 *
 * النظيرُ في التطبيقات `ArabicSearch` في mousqe_core بالقواعد نفسها، فيعطي البحثُ نفسُه في اللوحة
 * وفي برنامج الإدارة النتائجَ نفسَها.
 */
class ArabicSearch
{
    /** درجةُ التطابق: كلمةٌ كما هي، ثم بدايتها، ثم داخلها، ثم قريبةٌ منها بحرفٍ أو حرفين. */
    private const EXACT = 1.0;

    private const PREFIX = 0.85;

    private const CONTAINS = 0.7;

    private const NEAR = 0.55;

    /**
     * نصٌّ للمقارنة لا للعرض: بلا تشكيل ولا تطويل، والهمزات والتاء المربوطة والألف المقصورة موحّدة،
     * والأرقام لاتينية، و«عبد ‌X» و«أبو ‌X» كلمةٌ واحدة.
     */
    public static function normalize(?string $text): string
    {
        $text = mb_strtolower((string) $text);
        $text = (string) preg_replace('/[\x{064B}-\x{065F}\x{0670}\x{0640}]/u', '', $text);
        $text = strtr($text, [
            'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ٱ' => 'ا', 'ة' => 'ه', 'ى' => 'ي', 'ؤ' => 'و', 'ئ' => 'ي',
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4', '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
        ]);
        $text = (string) preg_replace('/[^\p{L}\p{N}]+/u', ' ', $text);
        $text = (string) preg_replace('/(?<=^|\s)(عبد|ابو)\s+/u', '$1', $text);

        return trim((string) preg_replace('/\s+/u', ' ', $text));
    }

    /**
     * @return list<string>
     */
    public static function words(?string $text): array
    {
        $normalized = self::normalize($text);

        return $normalized === '' ? [] : explode(' ', $normalized);
    }

    /**
     * مدى تطابق البحث مع حقول السجلّ: 0 لا تطابق، و1 تطابقٌ تامّ. لكل كلمةٍ في البحث أفضلُ ما تجده
     * في الحقول، والدرجةُ متوسّطها. و`$complete` أن تجد كلُّ كلمةٍ نفسَها (كاملةً أو بدايةً أو داخل
     * كلمة) لا قريبةً منها بالإملاء: القريبُ «أقربُ النتائج» حين لا يوجد غيره، لا نتيجةٌ بين النتائج.
     *
     * @param  list<string>  $fields  نصوص الحقول (اسم، كنية، رقم…)
     * @return array{score: float, complete: bool}
     */
    public static function match(string $query, array $fields): array
    {
        $needles = self::words($query);

        if ($needles === []) {
            return ['score' => 1.0, 'complete' => true];
        }

        $haystack = [];
        $digits = [];

        foreach ($fields as $field) {
            array_push($haystack, ...self::words($field));
            $digits[] = preg_replace('/\D/', '', (string) $field);
        }

        $total = 0.0;
        $complete = true;

        foreach ($needles as $needle) {
            $best = self::numeric($needle, $digits);

            foreach ($haystack as $word) {
                $best = max($best, self::wordScore($needle, $word));
            }

            $complete = $complete && $best >= self::CONTAINS;
            $total += $best;
        }

        return ['score' => $total / count($needles), 'complete' => $complete];
    }

    /**
     * يقصر استعلاماً على صفوفٍ يطابقها البحث في أعمدتها — للقوائم المرقَّمة في القاعدة: تُقرأ المفاتيح
     * والأعمدة وحدها، وتُطابَق هنا بالقواعد العربية، ثم يُكمَل الاستعلام بـ whereIn فيبقى ترقيمه كما هو.
     *
     * @template TBuilder of Builder
     *
     * @param  TBuilder  $query
     * @param  list<string>  $columns
     * @return TBuilder
     */
    public static function constrain(Builder $query, string $search, array $columns): Builder
    {
        if (self::words($search) === []) {
            return $query;
        }

        $model = $query->getModel();

        $ids = (clone $query)
            ->select([$model->getQualifiedKeyName(), ...array_map(fn (string $column) => $model->qualifyColumn($column), $columns)])
            ->toBase()
            ->get()
            ->filter(fn (object $row) => self::match($search, array_map(fn (string $column) => (string) ($row->{$column} ?? ''), $columns))['complete'])
            ->pluck($model->getKeyName());

        return $query->whereIn($model->getQualifiedKeyName(), $ids->all());
    }

    private static function wordScore(string $needle, string $word): float
    {
        if ($needle === $word) {
            return self::EXACT;
        }

        // «زغلول» تجد «الزغلول»: أداة التعريف لا تُحسب على الكلمة.
        $bare = (string) preg_replace('/^ال(?=\p{L}{2})/u', '', $word);

        if ($needle === $bare) {
            return self::EXACT - 0.05;
        }

        if (str_starts_with($word, $needle) || str_starts_with($bare, $needle)) {
            return self::PREFIX;
        }

        if (mb_strlen($needle) >= 2 && str_contains($word, $needle)) {
            return self::CONTAINS;
        }

        // قريبٌ بالإملاء: حرفٌ لكلمةٍ من 4 أحرف فأكثر، وحرفان من 7 فأكثر.
        $length = mb_strlen($needle);
        $allowed = $length >= 7 ? 2 : ($length >= 4 ? 1 : 0);

        if ($allowed > 0) {
            $distance = min(self::distance($needle, $word), self::distance($needle, $bare));

            if ($distance <= $allowed) {
                return self::NEAR - 0.1 * $distance;
            }
        }

        return 0.0;
    }

    /**
     * الأرقام (بطاقة، جوال) تُطابَق جزءاً من الرقم: «4994» تجد «0944994123».
     *
     * @param  list<string>  $digits
     */
    private static function numeric(string $needle, array $digits): float
    {
        if (! ctype_digit($needle) || strlen($needle) < 3) {
            return 0.0;
        }

        foreach ($digits as $number) {
            if ($number === $needle) {
                return self::EXACT;
            }

            if ($number !== '' && str_contains($number, $needle)) {
                return self::CONTAINS;
            }
        }

        return 0.0;
    }

    /**
     * مسافة التحرير بالمحارف لا بالبايتات — levenshtein() في PHP يعدّ بايتات UTF-8.
     */
    public static function distance(string $a, string $b): int
    {
        $a = mb_str_split($a);
        $b = mb_str_split($b);
        $previous = range(0, count($b));

        foreach ($a as $i => $charA) {
            $current = [$i + 1];

            foreach ($b as $j => $charB) {
                $current[] = min($previous[$j + 1] + 1, $current[$j] + 1, $previous[$j] + ($charA === $charB ? 0 : 1));
            }

            $previous = $current;
        }

        return $previous[count($b)];
    }
}
