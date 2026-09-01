<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Enums\Weekday;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CircleCumulativeStat;
use App\Models\CircleDailyStat;
use App\Models\CourseCircle;
use App\Support\HijriDate;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * تجميع تقرير يوم واحد لحلقة واحدة: القوائم، والنسبة، والترتيب في الدوام.
 *
 * مخرجه واحد تستهلكه ثلاث جهات — الشاشة، وقالب التقرير النصّي، وصفحة الطباعة/الـ PDF —
 * حتى لا تتفرّق الأرقام بين ثلاث حسابات متشابهة.
 */
class BuildCircleDailyReport
{
    /**
     * @return array{
     *     courseCircle: CourseCircle,
     *     session: AttendanceSession|null,
     *     daily: CircleDailyStat|null,
     *     cumulative: CircleCumulativeStat|null,
     *     lists: array<string, array<int, string>>,
     *     variables: array<string, string>
     * }
     */
    public function handle(CourseCircle $courseCircle, string $date): array
    {
        $courseCircle->loadMissing('circle', 'course.institute', 'shift', 'teachers');

        $session = $courseCircle->attendanceSessions()
            ->whereDate('session_date', $date)
            ->with('attendances.student')
            ->first();

        $daily = CircleDailyStat::query()
            ->where('course_circle_id', $courseCircle->id)
            ->whereDate('date', $date)
            ->first();

        $cumulative = CircleCumulativeStat::query()
            ->where('course_circle_id', $courseCircle->id)
            ->whereDate('as_of_date', '<=', $date)
            ->orderByDesc('as_of_date')
            ->first();

        $lists = $this->lists($session);

        return [
            'courseCircle' => $courseCircle,
            'session' => $session,
            'daily' => $daily,
            'cumulative' => $cumulative,
            'lists' => $lists,
            'variables' => $this->variables($courseCircle, $date, $daily, $cumulative, $lists),
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function lists(?AttendanceSession $session): array
    {
        $empty = ['present' => [], 'absent' => [], 'late' => [], 'excused' => []];

        if ($session === null) {
            return $empty;
        }

        /** @var Collection<int, Attendance> $attendances */
        $attendances = $session->attendances;

        foreach (AttendanceStatus::cases() as $status) {
            $empty[$status->value] = $attendances
                ->where('status', $status)
                ->map(fn ($attendance) => $attendance->student->full_name)
                ->sort()
                ->values()
                ->all();
        }

        return $empty;
    }

    /**
     * متغيّرات قوالب التقارير — تُستبدل حرفياً في نصّ القالب.
     *
     * @param  array<string, array<int, string>>  $lists
     * @return array<string, string>
     */
    private function variables(
        CourseCircle $courseCircle,
        string $date,
        ?CircleDailyStat $daily,
        ?CircleCumulativeStat $cumulative,
        array $lists,
    ): array {
        $carbon = Carbon::parse($date);

        return [
            'institute_name' => (string) $courseCircle->course->institute?->name,
            'course_name' => (string) $courseCircle->course->name,
            'circle_name' => (string) $courseCircle->circle->name,
            'shift_name' => (string) $courseCircle->shift->name,
            'room' => (string) ($courseCircle->room ?: '—'),
            'teacher_names' => $courseCircle->teachers->pluck('display_name')->join('، ') ?: '—',
            'date' => $carbon->toDateString(),
            'date_hijri' => HijriDate::long($carbon) ?? '—',
            'weekday' => Weekday::from($carbon->dayOfWeek)->label(),
            'present' => (string) ($daily?->present ?? count($lists['present'])),
            'absent' => (string) ($daily?->absent ?? count($lists['absent'])),
            'late' => (string) ($daily?->late ?? count($lists['late'])),
            'excused' => (string) ($daily?->excused ?? count($lists['excused'])),
            'total' => (string) ($daily?->total ?? array_sum(array_map('count', $lists))),
            'rate' => $daily ? rtrim(rtrim(number_format((float) $daily->attendance_rate, 2, '.', ''), '0'), '.').'%' : '—',
            'daily_rank' => (string) ($daily?->daily_rank_in_shift ?? '—'),
            'overall_rank' => (string) ($cumulative?->overall_rank_in_shift ?? '—'),
            'sessions_count' => (string) ($cumulative?->sessions_count ?? 0),
            'overall_rate' => $cumulative ? rtrim(rtrim(number_format((float) $cumulative->attendance_rate, 2, '.', ''), '0'), '.').'%' : '—',
            'present_list' => $lists['present'] === [] ? '—' : implode('، ', $lists['present']),
            'absent_list' => $lists['absent'] === [] ? '—' : implode('، ', $lists['absent']),
            'late_list' => $lists['late'] === [] ? '—' : implode('، ', $lists['late']),
            'excused_list' => $lists['excused'] === [] ? '—' : implode('، ', $lists['excused']),
            'session_status' => ($courseCircle->attendanceSessions()->whereDate('session_date', $date)->value('status') ?: SessionStatus::Draft->value),
        ];
    }
}
