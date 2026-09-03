<?php

namespace App\Actions;

use App\Enums\EnrollmentStatus;
use App\Models\CourseCircle;
use App\Models\Student;
use App\Queries\StudentPointsQuery;
use App\Support\DateRange;
use Illuminate\Support\Collection;

/**
 * تقرير نقاط حلقة خلال مدى تواريخ، مرتّباً تنازلياً بالمجموع.
 *
 * على نمط BuildCircleDailyReport: خرجٌ واحد يغذّي الشاشة وصفحة الطباعة معاً، فلا
 * يختلف رقمٌ بين ما يُرى وما يُطبع.
 */
class BuildCirclePointsReport
{
    public function __construct(private readonly StudentPointsQuery $points) {}

    /**
     * @return array{
     *     courseCircle: CourseCircle,
     *     range: DateRange,
     *     rows: Collection<int, array{rank: int, student: Student, quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}>,
     *     totals: array{quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}
     * }
     */
    public function handle(CourseCircle $courseCircle, DateRange $range): array
    {
        $courseCircle->loadMissing('circle.institute', 'course', 'shift', 'teachers');

        $students = Student::query()
            ->whereIn('id', $courseCircle->enrollments()->where('status', EnrollmentStatus::Active)->select('student_id'))
            ->get()
            ->keyBy('id');

        $totals = $this->points->forStudents($students->keys()->all(), $range->from, $range->to, $courseCircle->circle->institute);

        $rows = $this->rank(
            $totals
                ->map(fn (array $row, int $studentId) => [...$row, 'student' => $students->get($studentId)])
                ->filter(fn (array $row) => $row['student'] !== null)
                ->values()
        );

        return [
            'courseCircle' => $courseCircle,
            'range' => $range,
            'rows' => $rows,
            'totals' => $this->sum($rows),
        ];
    }

    /**
     * ترتيب تنافسي: المتساوون يأخذون الرتبة نفسها (1، 1، 3)، ويفصل التعادلَ اسمُ الطالب
     * لثبات الترتيب بين استدعاءين.
     *
     * @param  Collection<int, array<string, mixed>>  $rows
     * @return Collection<int, array<string, mixed>>
     */
    private function rank(Collection $rows): Collection
    {
        $sorted = $rows
            ->sort(fn (array $a, array $b) => [$b['total'], $a['student']->full_name] <=> [$a['total'], $b['student']->full_name])
            ->values();

        $rank = 0;
        $seen = 0;
        $previous = null;

        return $sorted->map(function (array $row) use (&$rank, &$seen, &$previous): array {
            $seen++;

            if ($row['total'] !== $previous) {
                $rank = $seen;
                $previous = $row['total'];
            }

            return [...$row, 'rank' => $rank];
        });
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $rows
     * @return array{quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}
     */
    private function sum(Collection $rows): array
    {
        return collect(array_keys(StudentPointsQuery::EMPTY))
            ->mapWithKeys(fn (string $key) => [$key => round((float) $rows->sum($key), 2)])
            ->all();
    }
}
