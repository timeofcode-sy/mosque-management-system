<?php

namespace App\Actions;

use App\Enums\MemorizationType;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Support\Quran;

/**
 * خريطة تقدّم الحفظ في المصحف: نسبة تغطية كل سورة من سجلّات الحفظ.
 *
 * التغطية تُبنى من مدَيات (from_surah, from_ayah) إلى (to_surah, to_ayah) لا من عدّاد
 * الصفحات، لأن المدى وحده يقول أين وصل الطالب — والصفحات تقول كم قطع فقط.
 */
class BuildStudentProgressMap
{
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
     * أعلى تغطية بلغَتها كل سورة عبر كل سجلّات الحفظ — لا مجموعها،
     * فمراجعة المدى نفسه مرّتين لا تعني حفظ ضعفه.
     *
     * @return array<int, int>
     */
    private function coveredAyahsBySurah(Student $student): array
    {
        $logs = MemorizationLog::query()
            ->where('student_id', $student->id)
            ->where('type', MemorizationType::Hifz)
            ->whereNotNull('from_surah')
            ->whereNotNull('to_surah')
            ->get(['from_surah', 'from_ayah', 'to_surah', 'to_ayah']);

        $covered = [];

        foreach ($logs as $log) {
            foreach (Quran::coverage((int) $log->from_surah, $log->from_ayah, (int) $log->to_surah, $log->to_ayah) as $surah => $count) {
                $covered[$surah] = max($covered[$surah] ?? 0, $count);
            }
        }

        return $covered;
    }
}
