<?php

namespace App\Queries;

use App\Enums\EnrollmentStatus;
use App\Models\CircleCumulativeStat;
use App\Models\CircleDailyStat;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * أرقام لوحة المعلومات: العدّادات، ونسبة اليوم، ومنحنى أسبوعين، وترتيب الحلقات.
 *
 * كل ما تحتاجه اللوحة يُجلب هنا في دفعة واحدة بدل أن يتناثر على خمس خصائص محسوبة
 * في ملف Blade، فيمكن اختبار الأرقام دون تصيير الشاشة.
 */
class DashboardOverviewQuery
{
    /**
     * @return array{students: int, enrolled: int, circles: int, teachers: int}
     */
    public function counters(?Institute $institute, ?Course $course): array
    {
        if ($institute === null) {
            return ['students' => 0, 'enrolled' => 0, 'circles' => 0, 'teachers' => 0];
        }

        return [
            'students' => Student::query()->where('institute_id', $institute->id)->count(),
            'teachers' => Teacher::query()->where('institute_id', $institute->id)->count(),
            'circles' => $course === null ? 0 : $course->courseCircles()->count(),
            'enrolled' => $course === null ? 0 : Enrollment::query()
                ->where('status', EnrollmentStatus::Active)
                ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $course->id))
                ->count(),
        ];
    }

    /**
     * حلقات الدورة مرتّبة بالدوام، ومعها المسجَّلون والنسبة التراكمية والترتيب الكلي.
     *
     * @return Collection<int, CourseCircle>
     */
    public function circles(?Course $course): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        $courseCircles = $course->courseCircles()
            ->with(['circle', 'shift.days', 'teachers'])
            ->withCount(['enrollments as active_enrollments_count' => fn ($query) => $query->where('status', EnrollmentStatus::Active)])
            ->get();

        $cumulative = $this->latestCumulative($courseCircles->modelKeys());

        return $courseCircles
            ->each(fn (CourseCircle $courseCircle) => $courseCircle->setRelation('standing', $cumulative->get($courseCircle->id)))
            ->sortBy(fn (CourseCircle $courseCircle) => [$courseCircle->shift->sort_order, $courseCircle->circle->sort_order])
            ->values();
    }

    /**
     * نسبة الحضور لكل يوم في آخر مدّة — مدخل المنحنى في اللوحة.
     *
     * @return Collection<int, array{date: string, rate: float, sessions: int}>
     */
    public function trend(?Course $course, int $days = 14): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        $from = Carbon::today()->subDays($days - 1);

        $stats = CircleDailyStat::query()
            ->whereIn('course_circle_id', $course->courseCircles()->select('id'))
            ->whereDate('date', '>=', $from->toDateString())
            ->get()
            ->groupBy(fn (CircleDailyStat $stat) => $stat->date->toDateString());

        return Collection::times($days, function (int $offset) use ($from, $stats): array {
            $date = $from->copy()->addDays($offset - 1)->toDateString();
            $day = $stats->get($date);

            return [
                'date' => $date,
                'rate' => $day === null ? 0.0 : $this->rateOf($day),
                'sessions' => $day?->count() ?? 0,
            ];
        });
    }

    /**
     * توزيع حالات الحضور (حاضر/غائب/متأخّر/مأذون) عبر آخر مدّة — لمخطط شريطي مكمّل للمنحنى.
     *
     * @return array{present: int, absent: int, late: int, excused: int}
     */
    public function statusBreakdown(?Course $course, int $days = 14): array
    {
        if ($course === null) {
            return ['present' => 0, 'absent' => 0, 'late' => 0, 'excused' => 0];
        }

        $from = Carbon::today()->subDays($days - 1);

        $stats = CircleDailyStat::query()
            ->whereIn('course_circle_id', $course->courseCircles()->select('id'))
            ->whereDate('date', '>=', $from->toDateString())
            ->get();

        return [
            'present' => (int) $stats->sum('present'),
            'absent' => (int) $stats->sum('absent'),
            'late' => (int) $stats->sum('late'),
            'excused' => (int) $stats->sum('excused'),
        ];
    }

    /**
     * نسبة حضور اليوم عبر كل حلقات الدورة.
     */
    public function rateOn(?Course $course, string $date): ?float
    {
        if ($course === null) {
            return null;
        }

        $stats = CircleDailyStat::query()
            ->whereIn('course_circle_id', $course->courseCircles()->select('id'))
            ->whereDate('date', $date)
            ->get();

        return $stats->isEmpty() ? null : $this->rateOf($stats);
    }

    /**
     * أحدث لقطة تراكمية لكل حلقة.
     *
     * @param  array<int, int>  $courseCircleIds
     * @return Collection<int, CircleCumulativeStat>
     */
    private function latestCumulative(array $courseCircleIds): Collection
    {
        if ($courseCircleIds === []) {
            return new Collection;
        }

        return CircleCumulativeStat::query()
            ->whereIn('course_circle_id', $courseCircleIds)
            ->orderBy('as_of_date')
            ->get()
            ->keyBy('course_circle_id');
    }

    /**
     * النسبة المجمّعة لمجموعة إحصاءات — بنفس معادلة RecalculateCircleStats
     * حتى لا يختلف رقم اللوحة عن رقم التقرير.
     *
     * @param  Collection<int, CircleDailyStat>  $stats
     */
    private function rateOf(Collection $stats): float
    {
        $countable = (int) $stats->sum(fn (CircleDailyStat $stat) => $stat->total - $stat->excused);

        if ($countable <= 0) {
            return 0.0;
        }

        $attended = (int) $stats->sum(fn (CircleDailyStat $stat) => $stat->present + $stat->late);

        return round($attended / $countable * 100, 1);
    }
}
