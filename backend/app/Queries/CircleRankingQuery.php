<?php

namespace App\Queries;

use App\Models\CircleCumulativeStat;
use App\Models\CircleDailyStat;
use App\Models\CourseCircle;
use App\Models\Shift;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * ترتيب حلقات الدوام — اليومي والكلي.
 *
 * القراءة من circle_daily_stats و circle_cumulative_stats مباشرةً، لا بإعادة عدّ
 * سجلّات الحضور: الترتيب حُسم لحظة إغلاق الجلسة في RecalculateCircleStats،
 * وإعادة حسابه هنا كانت ستفتح باب اختلاف الرقمين.
 *
 * مع كل حلقة يُرفَق مسارُ نسبها في آخر أسبوعين (recent_rates) — رقم الترتيب وحده
 * يقول أين الحلقة اليوم، والمسار يقول إلى أين تتّجه.
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

        $this->attachTrail($courseCircles, $date);

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

        $this->attachTrail($courseCircles, $asOf ?? Carbon::today()->toDateString());

        return $courseCircles
            ->each(fn (CourseCircle $courseCircle) => $courseCircle->setRelation('stat', $stats->get($courseCircle->id)))
            ->sortBy(fn (CourseCircle $courseCircle) => $courseCircle->stat?->overall_rank_in_shift ?? PHP_INT_MAX)
            ->values();
    }

    /**
     * نسب آخر أيام لكل حلقة، مرتّبةً زمنياً — مدخل الخط المصغّر في الجدول.
     *
     * استعلامٌ واحد لكل الحلقات لا استعلامٌ لكل صفّ.
     *
     * @param  Collection<int, CourseCircle>  $courseCircles
     */
    private function attachTrail(Collection $courseCircles, string $date, int $days = 14): void
    {
        $from = Carbon::parse($date)->subDays($days - 1)->toDateString();

        $trail = CircleDailyStat::query()
            ->whereIn('course_circle_id', $courseCircles->modelKeys())
            ->whereBetween('date', [$from, $date])
            ->orderBy('date')
            ->get(['course_circle_id', 'date', 'attendance_rate'])
            ->groupBy('course_circle_id');

        foreach ($courseCircles as $courseCircle) {
            $courseCircle->setAttribute(
                'recent_rates',
                ($trail->get($courseCircle->id)?->pluck('attendance_rate') ?? collect())
                    ->map(fn ($rate) => (float) $rate)
                    ->all(),
            );
        }
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    private function courseCircles(Shift $shift): Collection
    {
        return $shift->courseCircles()->with(['circle', 'teachers'])->get();
    }
}
