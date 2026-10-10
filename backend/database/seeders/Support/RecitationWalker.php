<?php

namespace Database\Seeders\Support;

use App\Support\Quran;

/**
 * يمشي بطالبٍ في المصحف مقطعاً بعد مقطع على ترتيب الحلقات:
 *
 * 1. جزء عمّ (30) من الناس صعوداً إلى النبأ — `amma`
 * 2. الجزء التاسع والعشرون (تبارك) — `tabarak`
 * 3. الجزء الثامن والعشرون (قد سمع) — `qad_sami`
 * 4. السور المنجيات — `munjiyat`
 * 5. القرآن من بدايته (الفاتحة فما بعدها) إلى الختم، دون ما حُفظ من قبل — `quran`
 *
 * كل مقطع داخل سورة واحدة (هو ما يفتحه نموذج التسميع) وطولُه بين ثلاثة أسطر وعشرين،
 * فتأتي المقاطع متجاورةً لا تتداخل — فلا يُحسب أي مقطع حفظٍ مكرّراً، وتساوي أسطرُه
 * الجديدة أسطرَه كلَّها كما يحسبها `SaveRecitation` على الخادم.
 */
final class RecitationWalker
{
    public const AMMA = 'amma';

    public const TABARAK = 'tabarak';

    public const QAD_SAMI = 'qad_sami';

    public const MUNJIYAT = 'munjiyat';

    public const QURAN = 'quran';

    /**
     * السور المنجيات: السجدة ويس والدخان والرحمن والواقعة. أما الملك فتأتي في جزء تبارك قبلها.
     *
     * @var array<int, int>
     */
    private const MUNJIYAT_SURAHS = [32, 36, 44, 55, 56];

    /**
     * @var array<string, array<int, int>> السور بترتيب الحفظ في كل مرحلة
     */
    private array $stages;

    /**
     * @var array<int, array{stage: string, index: int, surah: int}> الخطة مسطَّحةً
     */
    private array $sequence = [];

    private int $position = 0;

    private int $cursor = 1;

    public function __construct()
    {
        $stages = [
            self::AMMA => array_reverse(Quran::surahsOfJuz(30)),
            self::TABARAK => Quran::surahsOfJuz(29),
            self::QAD_SAMI => Quran::surahsOfJuz(28),
            self::MUNJIYAT => self::MUNJIYAT_SURAHS,
        ];

        $memorized = array_merge(...array_values($stages));
        $stages[self::QURAN] = array_values(array_diff(range(1, 114), $memorized));

        $this->stages = $stages;

        foreach ($stages as $stage => $surahs) {
            foreach ($surahs as $index => $surah) {
                $this->sequence[] = ['stage' => $stage, 'index' => $index, 'surah' => $surah];
            }
        }
    }

    /**
     * الجزء الذي تقع فيه آية. وهو دائماً جزءٌ تُعدّ سورتُها من سوره في `Quran::surahsOfJuz`،
     * فيقبله نموذج التسميع في اللوحة والتطبيقات كما هو.
     */
    public static function juzOf(int $surah, int $ayah): int
    {
        $juz = Quran::juzOf($surah, $ayah);

        return in_array($surah, Quran::surahsOfJuz($juz), true) ? $juz : Quran::juzOfSurah($surah);
    }

    /**
     * عدد آيات كل جزء، مفهرسة برقم الجزء.
     *
     * @return array<int, int>
     */
    public static function ayahsPerJuz(): array
    {
        return array_combine(range(1, 30), array_map(Quran::juzAyahs(...), range(1, 30)));
    }

    /**
     * المقاطع من الآن حتى يبلغ الطالب موضعاً في مرحلة: [$fraction] من سورها (0 ⇒ أولها، 1 ⇒ آخرها).
     *
     * @return array<int, array{surah: int, from: int, to: int, stage: string, index: int}>
     */
    public function walkTo(string $stage, float $fraction): array
    {
        $target = (int) floor($fraction * count($this->stages[$stage]));
        $chunks = [];

        while (($chunk = $this->next()) !== null) {
            $chunks[] = $chunk;

            if ($chunk['stage'] === $stage && $chunk['index'] >= $target) {
                break;
            }
        }

        return $chunks;
    }

    /**
     * المقاطع كلُّها حتى ختم القرآن.
     *
     * @return array<int, array{surah: int, from: int, to: int, stage: string, index: int}>
     */
    public function walkToEnd(): array
    {
        $chunks = [];

        while (($chunk = $this->next()) !== null) {
            $chunks[] = $chunk;
        }

        return $chunks;
    }

    /**
     * المقطع التالي، أو null إن انتهت الخطة.
     *
     * @return array{surah: int, from: int, to: int, stage: string, index: int}|null
     */
    public function next(): ?array
    {
        $step = $this->sequence[$this->position] ?? null;

        if ($step === null) {
            return null;
        }

        $surah = $step['surah'];
        $total = Quran::ayahs($surah);
        $from = $this->cursor;
        $linesPerAyah = Quran::lines($surah) / $total;
        $count = max(1, (int) round(fake()->numberBetween(3, 20) / $linesPerAyah));
        $to = min($total, $from + $count - 1);

        // لا يُترك من السورة ذيلٌ من آيةٍ أو اثنتين: يُضمّ إلى المقطع.
        if ($total - $to <= max(1, intdiv($count, 4))) {
            $to = $total;
        }

        if ($to === $total) {
            $this->position++;
            $this->cursor = 1;
        } else {
            $this->cursor = $to + 1;
        }

        return ['surah' => $surah, 'from' => $from, 'to' => $to, 'stage' => $step['stage'], 'index' => $step['index']];
    }
}
