<?php

namespace App\Actions;

use App\Models\Student;
use App\Support\Quran;

/**
 * خريطة تقدّم الحفظ في المصحف: نسبة تغطية كل سورة من سجلّات الحفظ.
 *
 * التغطية تُبنى من مدَيات (from_surah, from_ayah) إلى (to_surah, to_ayah) لا من عدّاد
 * الصفحات، لأن المدى وحده يقول أين وصل الطالب — والصفحات تقول كم قطع فقط. والجزء
 * المعلَّم «محفوظ» مدىً كذلك بحدوده (BuildStudentMemorizedMap).
 */
class BuildStudentProgressMap
{
    public function __construct(private readonly BuildStudentMemorizedMap $memorized) {}

    /**
     * @return array{
     *     surahs: array<int, array{number: int, name: string, ayahs: int, covered: int, ratio: float}>,
     *     memorized_ayahs: int,
     *     completed_surahs: int,
     *     overall_ratio: float
     * }
     */
    public function handle(Student $student): array
    {
        $covered = $this->coveredAyahsBySurah($student);

        $surahs = [];
        $memorized = 0;
        $completed = 0;

        foreach (Quran::SURAHS as $number => $surah) {
            $count = min($covered[$number] ?? 0, $surah['ayahs']);
            $ratio = $surah['ayahs'] > 0 ? $count / $surah['ayahs'] : 0.0;

            $memorized += $count;

            if ($ratio >= 1.0) {
                $completed++;
            }

            $surahs[$number] = [
                'number' => $number,
                'name' => $surah['name'],
                'ayahs' => $surah['ayahs'],
                'covered' => $count,
                'ratio' => round($ratio, 4),
            ];
        }

        return [
            'surahs' => $surahs,
            'memorized_ayahs' => $memorized,
            'completed_surahs' => $completed,
            'overall_ratio' => round($memorized / Quran::TOTAL_AYAHS, 4),
        ];
    }

    /**
     * آيات كل سورة المحفوظة: اتّحاد المدَيات لا مجموعها، فمراجعة المدى نفسه مرّتين
     * لا تعني حفظ ضعفه، ومدَيان متداخلان لا يُحسب تقاطعهما مرّتين.
     *
     * @return array<int, int>
     */
    private function coveredAyahsBySurah(Student $student): array
    {
        $covered = [];

        foreach ($this->memorized->handle($student) as $surah => $ranges) {
            $covered[$surah] = array_sum(array_map(fn (array $range) => $range[1] - $range[0] + 1, $ranges));
        }

        return $covered;
    }
}
