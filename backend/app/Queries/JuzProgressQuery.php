<?php

namespace App\Queries;

use App\Enums\ProgressStatus;
use App\Models\StudentCurriculumProgress;

/**
 * الأجزاءُ الثلاثون لكل طالب كما يرسمها شريطُ الأجزاء (`<x-juz-progress>`): المحفوظُ منها، والذي
 * يُحفظ الآن.
 *
 * بنودُ القرآن رموزُها `juz-N` — القاعدةُ نفسُها التي يعدّ بها `StudentListQuery` الأجزاءَ
 * المحفوظة. والمحفوظُ والمتقَنُ محفوظ، والجاري الأكثرُ تقدّماً هو الحالي. استعلامٌ واحدٌ لطلاب
 * الحلقة كلِّهم لا استعلامٌ لكل صفّ.
 */
class JuzProgressQuery
{
    /**
     * @param  iterable<int>  $studentIds
     * @return array<int, array{memorized: array<int, int>, current: ?int}>
     */
    public function forStudents(iterable $studentIds): array
    {
        $ids = collect($studentIds)->unique()->values();

        if ($ids->isEmpty()) {
            return [];
        }

        $rows = StudentCurriculumProgress::query()
            ->join('curriculum_items', 'curriculum_items.id', '=', 'student_curriculum_progress.curriculum_item_id')
            ->whereIn('student_curriculum_progress.student_id', $ids)
            ->where('curriculum_items.code', 'like', 'juz-%')
            ->whereIn('student_curriculum_progress.status', [
                ProgressStatus::Memorized->value,
                ProgressStatus::Mastered->value,
                ProgressStatus::InProgress->value,
            ])
            ->get([
                'student_curriculum_progress.student_id',
                'student_curriculum_progress.status',
                'student_curriculum_progress.percent',
                'curriculum_items.code',
            ]);

        $result = [];

        foreach ($rows->groupBy('student_id') as $studentId => $progress) {
            $memorized = [];
            $current = null;
            $currentPercent = -1;

            foreach ($progress as $row) {
                $juz = self::juzOf((string) $row->getAttribute('code'));

                if ($juz === null) {
                    continue;
                }

                if ($row->status === ProgressStatus::InProgress) {
                    if ((int) $row->percent > $currentPercent) {
                        $current = $juz;
                        $currentPercent = (int) $row->percent;
                    }

                    continue;
                }

                $memorized[] = $juz;
            }

            sort($memorized);

            $result[(int) $studentId] = [
                'memorized' => array_values(array_unique($memorized)),
                'current' => in_array($current, $memorized, true) ? null : $current,
            ];
        }

        return $result;
    }

    /**
     * @return array{memorized: array<int, int>, current: ?int}
     */
    public function forStudent(int $studentId): array
    {
        return $this->forStudents([$studentId])[$studentId] ?? ['memorized' => [], 'current' => null];
    }

    public static function juzOf(string $code): ?int
    {
        if (! preg_match('/^juz-(\d+)$/', $code, $match)) {
            return null;
        }

        $juz = (int) $match[1];

        return $juz >= 1 && $juz <= 30 ? $juz : null;
    }
}
