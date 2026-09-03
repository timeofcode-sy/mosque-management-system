<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\CircleCumulativeStat;
use App\Models\CircleDailyStat;
use App\Models\CourseCircle;
use App\Support\AttendanceRate;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * حساب إحصاء الحلقات وترتيبها داخل الدوام.
 *
 * التصنيف اليومي: ترتيب الحلقة بين حلقات نفس الدوام حسب نسبة حضور ذلك اليوم.
 * التصنيف الكلي: الترتيب حسب المعدّل التراكمي منذ بداية الدورة حتى ذلك التاريخ.
 *
 * النسبة = (حاضر + متأخّر) على (المجموع ناقص المأذون). الإذن المسبق لا يُحسب غياباً
 * على الحلقة، وإلا عاقب الترتيبُ الحلقةَ على ظرف خارج يدها.
 */
class RecalculateCircleStats
{
    /**
     * يعيد الحساب لكل حلقات الدوام في ذلك اليوم — لأن الترتيب نسبيّ بطبعه
     * فلا معنى لتحديث حلقة واحدة دون جاراتها.
     */
    public function handle(int $shiftId, string $date): void
    {
        $courseCircles = CourseCircle::query()->where('shift_id', $shiftId)->get();

        if ($courseCircles->isEmpty()) {
            return;
        }

        DB::transaction(function () use ($courseCircles, $date): void {
            foreach ($courseCircles as $courseCircle) {
                $this->writeDaily($courseCircle, $date);
                $this->writeCumulative($courseCircle, $date);
            }

            $this->rankDaily($courseCircles, $date);
            $this->rankCumulative($courseCircles, $date);
        });
    }

    /**
     * إعادة حساب دورة كاملة — يستدعيها الأمر mousqe:recalculate-stats والبذور.
     */
    public function forCourse(int $courseId): void
    {
        $dates = DB::table('attendance_sessions')
            ->join('course_circles', 'course_circles.id', '=', 'attendance_sessions.course_circle_id')
            ->whereNull('attendance_sessions.deleted_at')
            ->where('course_circles.course_id', $courseId)
            ->whereIn('attendance_sessions.status', [SessionStatus::Completed->value, SessionStatus::Locked->value])
            ->distinct()
            ->orderBy('attendance_sessions.session_date')
            ->pluck('attendance_sessions.session_date');

        $shiftIds = CourseCircle::query()->where('course_id', $courseId)->distinct()->pluck('shift_id');

        foreach ($dates as $date) {
            foreach ($shiftIds as $shiftId) {
                $this->handle((int) $shiftId, substr((string) $date, 0, 10));
            }
        }
    }

    private function writeDaily(CourseCircle $courseCircle, string $date): void
    {
        $session = $courseCircle->attendanceSessions()
            ->whereDate('session_date', $date)
            ->whereIn('status', [SessionStatus::Completed, SessionStatus::Locked])
            ->first();

        if ($session === null) {
            CircleDailyStat::query()
                ->where('course_circle_id', $courseCircle->id)
                ->whereDate('date', $date)
                ->delete();

            return;
        }

        $counts = $this->countByStatus(Attendance::query()->where('attendance_session_id', $session->id));

        CircleDailyStat::updateOrCreate(
            ['course_circle_id' => $courseCircle->id, 'date' => $date],
            [...$counts, 'attendance_rate' => $this->rate($counts)],
        );
    }

    private function writeCumulative(CourseCircle $courseCircle, string $date): void
    {
        $daily = CircleDailyStat::query()
            ->where('course_circle_id', $courseCircle->id)
            ->whereDate('date', '<=', $date)
            ->get();

        if ($daily->isEmpty()) {
            CircleCumulativeStat::query()
                ->where('course_circle_id', $courseCircle->id)
                ->whereDate('as_of_date', $date)
                ->delete();

            return;
        }

        $counts = [
            'present' => (int) $daily->sum('present'),
            'absent' => (int) $daily->sum('absent'),
            'late' => (int) $daily->sum('late'),
            'excused' => (int) $daily->sum('excused'),
            'total' => (int) $daily->sum('total'),
        ];

        CircleCumulativeStat::updateOrCreate(
            ['course_circle_id' => $courseCircle->id, 'as_of_date' => $date],
            [...$counts, 'sessions_count' => $daily->count(), 'attendance_rate' => $this->rate($counts)],
        );
    }

    /**
     * @param  Collection<int, CourseCircle>  $courseCircles
     */
    private function rankDaily(Collection $courseCircles, string $date): void
    {
        $stats = CircleDailyStat::query()
            ->whereIn('course_circle_id', $courseCircles->modelKeys())
            ->whereDate('date', $date)
            ->get();

        $this->assignRanks($stats, 'daily_rank_in_shift');
    }

    /**
     * @param  Collection<int, CourseCircle>  $courseCircles
     */
    private function rankCumulative(Collection $courseCircles, string $date): void
    {
        $stats = CircleCumulativeStat::query()
            ->whereIn('course_circle_id', $courseCircles->modelKeys())
            ->whereDate('as_of_date', $date)
            ->get();

        $this->assignRanks($stats, 'overall_rank_in_shift');
    }

    /**
     * الترتيب بالنسبة نازلاً، ويفصل التعادلَ عددُ الحاضرين ثم معرّف الحلقة لثبات النتيجة.
     * الحلقات المتعادلة تأخذ الرتبة نفسها (ترتيب تنافسي: 1، 1، 3).
     *
     * @param  Collection<int, CircleDailyStat|CircleCumulativeStat>  $stats
     */
    private function assignRanks(Collection $stats, string $column): void
    {
        // مقارِن صريح لا مصفوفة إغلاقات: sortBy بمصفوفة يستدعي كل إغلاق مقارِناً
        // بوسيطين ($a, $b) لا مستخرِجَ مفتاح. والإغلاق أحاديّ الوسيط يتجاهل $b
        // فيعيد قيمةً ثابتة الإشارة، فيصير المقارِن غير متّسق وتبقى المجموعة
        // بترتيب الإدخال بلا ترتيب أصلاً. يحرس ذلك CircleStatsTest.
        $sorted = $stats
            ->sort(fn ($a, $b) => [(float) $b->attendance_rate, (int) $b->present, (int) $a->course_circle_id]
                <=> [(float) $a->attendance_rate, (int) $a->present, (int) $b->course_circle_id])
            ->values();

        $rank = 0;
        $seen = 0;
        $previous = null;

        foreach ($sorted as $stat) {
            $seen++;
            $key = [(float) $stat->attendance_rate, (int) $stat->present];

            if ($key !== $previous) {
                $rank = $seen;
                $previous = $key;
            }

            $stat->forceFill([$column => $rank])->save();
        }
    }

    /**
     * @param  Builder<Attendance>  $query
     * @return array<string, int>
     */
    private function countByStatus(Builder $query): array
    {
        $counts = $query
            ->selectRaw('status, count(*) as aggregate')
            ->groupBy('status')
            ->pluck('aggregate', 'status');

        $present = (int) ($counts[AttendanceStatus::Present->value] ?? 0);
        $absent = (int) ($counts[AttendanceStatus::Absent->value] ?? 0);
        $late = (int) ($counts[AttendanceStatus::Late->value] ?? 0);
        $excused = (int) ($counts[AttendanceStatus::Excused->value] ?? 0);

        return [
            'present' => $present,
            'absent' => $absent,
            'late' => $late,
            'excused' => $excused,
            'total' => $present + $absent + $late + $excused,
        ];
    }

    /**
     * @param  array{present: int, late: int, excused: int, total: int}  $counts
     */
    private function rate(array $counts): float
    {
        return AttendanceRate::of($counts, precision: 2);
    }
}
