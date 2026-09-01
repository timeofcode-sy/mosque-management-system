<?php

namespace App\Queries;

use App\Enums\EnrollmentStatus;
use App\Enums\Weekday;
use App\Models\AttendanceSession;
use App\Models\CircleDailyStat;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Shift;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * لوح التفقّد اليومي: أي حلقات تُتفقَّد في هذا التاريخ، وأين وصلت كل جلسة.
 */
class AttendanceBoardQuery
{
    /**
     * @return Collection<int, Shift>
     */
    public function shifts(?Course $course): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        return $course->shifts()->with('days')->orderBy('sort_order')->get();
    }

    /**
     * الدوامات التي يقع فيها هذا اليوم من الأسبوع.
     *
     * @param  Collection<int, Shift>  $shifts
     * @return Collection<int, Shift>
     */
    public function shiftsOn(Collection $shifts, string $date): Collection
    {
        $weekday = Weekday::from(Carbon::parse($date)->dayOfWeek)->value;

        return $shifts->filter(fn (Shift $shift) => in_array($weekday, $shift->weekdays(), true))->values();
    }

    /**
     * صفوف اللوح: حلقة + حالة جلستها في التاريخ + إحصاء اليوم إن حُسب.
     *
     * حين لا يقع اليوم في أي دوام تُعرض كل الدوامات بدل قائمة فارغة — التفقّد
     * الاستدراكي في يوم عطلة وارد، وإخفاء الحلقات يجعل الشاشة تبدو معطوبة.
     *
     * @return Collection<int, CourseCircle>
     */
    public function rows(?Course $course, string $date, ?int $shiftId = null): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        $shifts = $this->shifts($course);
        $scheduled = $this->shiftsOn($shifts, $date);

        $shiftIds = $shiftId !== null
            ? [$shiftId]
            : ($scheduled->isNotEmpty() ? $scheduled->modelKeys() : $shifts->modelKeys());

        if ($shiftIds === []) {
            return new Collection;
        }

        $courseCircles = $course->courseCircles()
            ->whereIn('shift_id', $shiftIds)
            ->with(['circle', 'shift.days', 'teachers'])
            ->withCount(['enrollments as active_enrollments_count' => fn ($query) => $query->where('status', EnrollmentStatus::Active)])
            ->get();

        $sessions = $this->sessionStatuses($courseCircles->modelKeys(), $date);
        $stats = $this->dailyStats($courseCircles->modelKeys(), $date);

        return $courseCircles
            ->each(function (CourseCircle $courseCircle) use ($sessions, $stats): void {
                $courseCircle->setAttribute('session_status', $sessions[$courseCircle->id] ?? null);
                $courseCircle->setRelation('todayStat', $stats->get($courseCircle->id));
            })
            ->sortBy(fn (CourseCircle $courseCircle) => [$courseCircle->shift->sort_order, $courseCircle->circle->sort_order])
            ->values();
    }

    /**
     * @param  array<int, int>  $courseCircleIds
     * @return Collection<int, string>
     */
    private function sessionStatuses(array $courseCircleIds, string $date): Collection
    {
        if ($courseCircleIds === []) {
            return new Collection;
        }

        return AttendanceSession::query()
            ->whereIn('course_circle_id', $courseCircleIds)
            ->whereDate('session_date', $date)
            ->pluck('status', 'course_circle_id')
            ->map(fn ($status) => is_string($status) ? $status : $status->value);
    }

    /**
     * @param  array<int, int>  $courseCircleIds
     * @return Collection<int, CircleDailyStat>
     */
    private function dailyStats(array $courseCircleIds, string $date): Collection
    {
        if ($courseCircleIds === []) {
            return new Collection;
        }

        return CircleDailyStat::query()
            ->whereIn('course_circle_id', $courseCircleIds)
            ->whereDate('date', $date)
            ->get()
            ->keyBy('course_circle_id');
    }
}
