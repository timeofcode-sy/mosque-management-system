<?php

namespace App\Actions;

use App\Enums\MemorizationType;
use App\Enums\ProgressStatus;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Support\Quran;

/**
 * ما يحفظه الطالب من المصحف بدقّة الآية، من مصدرين معاً:
 *
 * 1. مدَيات الحفظ المسمَّعة (memorization_logs من نوع «حفظ»).
 * 2. الأجزاء المعلَّمة «محفوظ» في المحفوظات — حفظٌ سابق للمعهد لا تسميع له، يُفرد
 *    بحدود الجزء بالآية (الجزء الأول: الفاتحة 1 ← البقرة 141).
 *
 * فيتّفق الجزء وسوره: تعليم الجزء محفوظاً يملأ سوره في خريطة المصحف، وتسميع آيات
 * الجزء يرفع نسبته.
 */
class BuildStudentMemorizedMap
{
    /**
     * @return array<int, array<int, array{int, int}>> [رقم السورة => مدَيات [من، إلى] مرتّبة ومدمَجة]
     */
    public function handle(Student $student): array
    {
        $bySurah = [];

        $logs = MemorizationLog::query()
            ->where('student_id', $student->id)
            ->where('type', MemorizationType::Hifz)
            ->whereNotNull('from_surah')
            ->whereNotNull('to_surah')
            ->get(['from_surah', 'from_ayah', 'to_surah', 'to_ayah']);

        foreach ($logs as $log) {
            foreach (Quran::segments((int) $log->from_surah, $log->from_ayah, (int) $log->to_surah, $log->to_ayah) as $surah => $range) {
                $bySurah[$surah][] = $range;
            }
        }

        foreach ($this->memorizedJuz($student) as $juz) {
            foreach (Quran::juzSegments($juz) as $surah => $range) {
                $bySurah[$surah][] = $range;
            }
        }

        ksort($bySurah);

        return array_map(BuildStudentCoverageMap::merge(...), $bySurah);
    }

    /**
     * الآيات المحفوظة من مقطع [start, end] في سورة.
     *
     * @param  array<int, array<int, array{int, int}>>  $map
     */
    public static function coveredIn(array $map, int $surah, int $start, int $end): int
    {
        $covered = 0;

        foreach ($map[$surah] ?? [] as [$rangeStart, $rangeEnd]) {
            $covered += max(0, min($end, $rangeEnd) - max($start, $rangeStart) + 1);
        }

        return $covered;
    }

    /**
     * الآيات المحفوظة من جزء.
     *
     * @param  array<int, array<int, array{int, int}>>  $map
     */
    public static function coveredInJuz(array $map, int $juz): int
    {
        $covered = 0;

        foreach (Quran::juzSegments($juz) as $surah => [$start, $end]) {
            $covered += self::coveredIn($map, $surah, $start, $end);
        }

        return $covered;
    }

    /**
     * @return array<int, int> أرقام الأجزاء المعلَّمة «محفوظ»
     */
    private function memorizedJuz(Student $student): array
    {
        return StudentCurriculumProgress::query()
            ->where('student_id', $student->id)
            ->where('status', ProgressStatus::Memorized)
            ->with('curriculumItem.curriculum')
            ->get()
            ->map(fn (StudentCurriculumProgress $progress) => $progress->curriculumItem?->juz())
            ->filter()
            ->unique()
            ->values()
            ->all();
    }
}
