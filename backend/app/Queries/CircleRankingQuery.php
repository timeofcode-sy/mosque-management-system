<?php

namespace App\Queries;

use App\Models\CircleCumulativeStat;
use App\Models\CircleDailyStat;
use App\Models\CourseCircle;
use App\Models\Shift;
use Illuminate\Support\Collection;

/**
 * ترتيب حلقات الدوام — اليومي والكلي.
 *
 * القراءة من circle_daily_stats و circle_cumulative_stats مباشرةً، لا بإعادة عدّ
 * سجلّات الحضور: الترتيب حُسم لحظة إغلاق الجلسة في RecalculateCircleStats،
 * وإعادة حسابه هنا كانت ستفتح باب اختلاف الرقمين.
 */
class CircleRankingQuery
{
    /**
     * @return Collection<int, CourseCircle>
     */
    public function daily(Shift $shift, string $date): Collection
    {
        $courseCircles = $this->courseCircles($shift);

        $stats = CircleDailyStat::query()
            ->whereIn('course_circle_id', $courseCircles->modelKeys())
            ->whereDate('date', $date)
            ->get()
            ->keyBy('course_circle_id');

        return $courseCircles
            ->each(fn (CourseCircle $courseCircle) => $courseCircle->setRelation('stat', $stats->get($courseCircle->id)))
            ->sortBy(fn (CourseCircle $courseCircle) => $courseCircle->stat?->daily_rank_in_shift ?? PHP_INT_MAX)
            ->values();
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    public function cumulative(Shift $shift, ?string $asOf = null): Collection
    {
        $courseCircles = $this->courseCircles($shift);

        $query = CircleCumulativeStat::query()
            ->whereIn('course_circle_id', $courseCircles->modelKeys());

        if ($asOf !== null) {
            $query->whereDate('as_of_date', '<=', $asOf);
        }

        $stats = $query->orderBy('as_of_date')->get()->keyBy('course_circle_id');

        return $courseCircles
            ->each(fn (CourseCircle $courseCircle) => $courseCircle->setRelation('stat', $stats->get($courseCircle->id)))
            ->sortBy(fn (CourseCircle $courseCircle) => $courseCircle->stat?->overall_rank_in_shift ?? PHP_INT_MAX)
            ->values();
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    private function courseCircles(Shift $shift): Collection
    {
        return $shift->courseCircles()->with(['circle', 'teachers'])->get();
    }
}
