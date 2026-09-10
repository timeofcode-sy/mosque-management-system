<?php

namespace App\Queries;

use App\Enums\AttendanceStatus;
use App\Enums\ProgressStatus;
use App\Models\Attendance;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\StudentTransfer;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * قراءات ملف الطالب: مساره، ونقله، ومحفوظاته، وحضوره ومنحناه الشهري.
 */
class StudentProfileQuery
{
    /**
     * @return Collection<int, Enrollment>
     */
    public function enrollments(Student $student): Collection
    {
        return $student->enrollments()
            ->with('courseCircle.circle', 'courseCircle.course', 'courseCircle.shift')
            ->orderByDesc('enrolled_on')
            ->get();
    }

    /**
     * @return Collection<int, StudentTransfer>
     */
    public function transfers(Student $student): Collection
    {
        return $student->transfers()
            ->with('fromCourseCircle.circle', 'toCourseCircle.circle', 'performedBy')
            ->orderByDesc('transferred_on')
            ->get();
    }

    /**
     * المحفوظات مجمَّعة بالمنهج.
     *
     * @return Collection<string, Collection<int, StudentCurriculumProgress>>
     */
    public function progressByCurriculum(Student $student): Collection
    {
        return $student->curriculumProgress()
            ->with('curriculumItem.curriculum')
            ->whereIn('status', [ProgressStatus::InProgress, ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->get()
            ->groupBy(fn ($progress) => $progress->curriculumItem->curriculum->name);
    }

    /**
     * @return Collection<int, Attendance>
     */
    public function recentAttendances(Student $student, int $limit = 20): Collection
    {
        return $student->attendances()
            ->with('attendanceSession.courseCircle.circle')
            ->latest('recorded_at')
            ->limit($limit)
            ->get();
    }

    /**
     * توزيع حالات الحضور عبر كل السجل.
     *
     * @return array{present: int, absent: int, late: int, excused: int, total: int, rate: float|null}
     */
    public function attendanceSummary(Student $student): array
    {
        $counts = $student->attendances()
            ->selectRaw('status, count(*) as aggregate')
            ->groupBy('status')
            ->pluck('aggregate', 'status');

        $present = (int) ($counts[AttendanceStatus::Present->value] ?? 0);
        $absent = (int) ($counts[AttendanceStatus::Absent->value] ?? 0);
        $late = (int) ($counts[AttendanceStatus::Late->value] ?? 0);
        $excused = (int) ($counts[AttendanceStatus::Excused->value] ?? 0);
        $total = $present + $absent + $late + $excused;
        $countable = $total - $excused;

        return [
            'present' => $present,
            'absent' => $absent,
            'late' => $late,
            'excused' => $excused,
            'total' => $total,
            'rate' => $countable > 0 ? round(($present + $late) / $countable * 100, 1) : null,
        ];
    }

    /**
     * نسبة حضور الطالب في كل يوم من آخر مدّة — مدخل منحنى ملف الطالب.
     *
     * 🔑 م.7.1: **يومٌ بلا جلسة `rate: null` لا `0.0`** — وهي قاعدةُ م.6.6 حرفياً
     * («ما لم يُسجَّل لا يُفترض، و`null` ليست صفراً» —
     * [CHECKPOINT-PHASE-6.6.MD §3](../../../docs/CHECKPOINT-PHASE-6.6.MD)) مطبَّقةً
     * على السطح الخادمي بعد أن طُبِّقت في `StatsRepository` على سطح الديسكتوب.
     *
     * الصفرُ كان يقول «حضر صفراً بالمئة» عن يومِ جمعةٍ لا تفقّدَ فيه أصلاً. لم
     * يكن يظهر في اللوحة لأن مكوّنَ المنحنى يرشّح النقاطَ بـ`sessions > 0` قبل
     * رسم دوائرها — لكنّ **الخطَّ نفسَه** كان يهبط إليها، ولا مرشِّحَ في نقطة
     * الـAPI إطلاقاً. وشاشةُ ولي الأمر تعرض السجلَّ يوماً بيوم لقارئٍ ليس طاقماً
     * ولا يعرف أيُّ يومٍ يومُ دوام.
     *
     * @return Collection<int, array{date: string, rate: float|null, sessions: int}>
     */
    public function attendanceTrend(Student $student, int $days = 30): Collection
    {
        $from = Carbon::today()->subDays($days - 1);

        $byDate = $student->attendances()
            ->with('attendanceSession:id,session_date')
            ->whereHas('attendanceSession', fn ($query) => $query->whereDate('session_date', '>=', $from->toDateString()))
            ->get()
            ->groupBy(fn (Attendance $attendance) => $attendance->attendanceSession->session_date->toDateString());

        return Collection::times($days, function (int $offset) use ($from, $byDate): array {
            $date = $from->copy()->addDays($offset - 1)->toDateString();
            $day = $byDate->get($date);

            if ($day === null || $day->isEmpty()) {
                return ['date' => $date, 'rate' => null, 'sessions' => 0];
            }

            $countable = $day->whereNotIn('status', [AttendanceStatus::Excused])->count();
            $attended = $day->whereIn('status', [AttendanceStatus::Present, AttendanceStatus::Late])->count();

            return [
                'date' => $date,
                // ويومٌ كلُّ سجلّاته «مأذون» ⇒ null كذلك لا صفر: المأذونُ خارج
                // المقام في معادلة النسبة، فيومٌ لا مقامَ له لا نسبةَ له.
                'rate' => $countable > 0 ? round($attended / $countable * 100, 1) : null,
                'sessions' => $day->count(),
            ];
        });
    }
}
