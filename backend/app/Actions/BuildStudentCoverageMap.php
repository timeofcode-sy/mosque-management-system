<?php

namespace App\Actions;

use App\Models\MemorizationLog;
use App\Models\Student;
use App\Support\Quran;

/**
 * ما سمّعه الطالب من المصحف، كمدَيات مدمَجة لكل سورة.
 *
 * جارة BuildStudentProgressMap: تلك تعطي «كم حُفظ» لرسم الخريطة، وهذه تعطي «أين»
 * بدقّة الآية — وهو ما يلزم لأمرين: احتساب الجديد دون المكرّر، واقتراح المقطع
 * غير المكتمل في نموذج التسميع.
 */
class BuildStudentCoverageMap
{
    /**
     * @param  int|null  $excludeLogId  سجلّ يُستثنى من الخريطة — يستعمله التعديل كي لا
     *                                  يحسب السجلّ نفسه مكرّراً لنفسه
     * @return array<int, array<int, array{int, int}>> [رقم السورة => مدَيات [من، إلى] مرتّبة ومدمَجة]
     */
    public function handle(Student $student, ?int $excludeLogId = null): array
    {
        $logs = MemorizationLog::query()
            ->where('student_id', $student->id)
            ->whereNotNull('from_surah')
            ->whereNotNull('to_surah')
            ->when($excludeLogId !== null, fn ($query) => $query->whereKeyNot($excludeLogId))
            ->get(['from_surah', 'from_ayah', 'to_surah', 'to_ayah']);

        $bySurah = [];

        foreach ($logs as $log) {
            $segments = Quran::segments((int) $log->from_surah, $log->from_ayah, (int) $log->to_surah, $log->to_ayah);

            foreach ($segments as $surah => $range) {
                $bySurah[$surah][] = $range;
            }
        }

        return array_map(self::merge(...), $bySurah);
    }

    /**
     * الآيات التي لم يسبق للطالب تسميعها من مدى جديد، مفهرسة بالسورة.
     *
     * @param  array<int, array<int, array{int, int}>>  $map
     * @return array<int, int>
     */
    public static function newAyahsIn(array $map, int $fromSurah, ?int $fromAyah, int $toSurah, ?int $toAyah): array
    {
        $new = [];

        foreach (Quran::segments($fromSurah, $fromAyah, $toSurah, $toAyah) as $surah => [$start, $end]) {
            $count = $end - $start + 1;

            foreach ($map[$surah] ?? [] as [$coveredStart, $coveredEnd]) {
                $overlap = min($end, $coveredEnd) - max($start, $coveredStart) + 1;

                if ($overlap > 0) {
                    $count -= $overlap;
                }
            }

            $new[$surah] = max(0, $count);
        }

        return $new;
    }

    /**
     * أوّل مقطع غير مغطّى في سورة — افتراض نموذج التسميع (الملك 1–12 مسجّلة ⇒ 13–30).
     *
     * @param  array<int, array<int, array{int, int}>>  $map
     * @return array{int, int}
     */
    public static function firstGapIn(array $map, int $surah): array
    {
        $last = Quran::ayahs($surah);
        $cursor = 1;

        foreach ($map[$surah] ?? [] as [$start, $end]) {
            if ($start > $cursor) {
                return [$cursor, $start - 1];
            }

            $cursor = max($cursor, $end + 1);
        }

        return $cursor > $last ? [1, $last] : [$cursor, $last];
    }

    /**
     * دمج المدَيات المتداخلة أو المتلاصقة في مدَيات متفرّقة مرتّبة.
     *
     * @param  array<int, array{int, int}>  $ranges
     * @return array<int, array{int, int}>
     */
    private static function merge(array $ranges): array
    {
        usort($ranges, fn (array $a, array $b) => $a[0] <=> $b[0]);

        $merged = [];

        foreach ($ranges as [$start, $end]) {
            $last = array_key_last($merged);

            if ($last !== null && $start <= $merged[$last][1] + 1) {
                $merged[$last][1] = max($merged[$last][1], $end);

                continue;
            }

            $merged[] = [$start, $end];
        }

        return $merged;
    }
}
