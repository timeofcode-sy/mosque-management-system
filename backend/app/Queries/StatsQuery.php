<?php

namespace App\Queries;

use App\Enums\EnrollmentStatus;
use App\Enums\NotePolarity;
use App\Models\Attendance;
use App\Models\CircleDailyStat;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Support\AttendanceRate;
use App\Support\DateRange;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

/**
 * ترتيبات شاشة الإحصائيات: كيان (حلقات/طلاب) × مقياس (حضور/تسميع/نقاط/أدب) × مدى.
 *
 * كل مقياس يُبنى على مصدره الطبيعي — الحضور من circle_daily_stats المجمّعة مسبقاً
 * للحلقات ومن attendances للطلاب — بدل أن يُعاد حسابه من الصفر في كل مرّة.
 */
class StatsQuery
{
    public const ENTITY_CIRCLES = 'circles';

    public const ENTITY_STUDENTS = 'students';

    public const METRIC_ATTENDANCE = 'attendance';

    public const METRIC_RECITATION = 'recitation';

    public const METRIC_POINTS = 'points';

    public const METRIC_MANNERS = 'manners';

    public function __construct(private readonly StudentPointsQuery $points) {}

    /**
     * @return array<string, string>
     */
    public static function entities(): array
    {
        return [self::ENTITY_CIRCLES => 'الحلقات', self::ENTITY_STUDENTS => 'الطلاب'];
    }

    /**
     * @return array<string, string>
     */
    public static function metrics(): array
    {
        return [
            self::METRIC_ATTENDANCE => 'حضوراً',
            self::METRIC_RECITATION => 'تسميعاً',
            self::METRIC_POINTS => 'نقاطاً',
            self::METRIC_MANNERS => 'أدباً',
        ];
    }

    /**
     * وحدة القياس المعروضة بجانب الرقم.
     */
    public static function unit(string $metric): string
    {
        return match ($metric) {
            self::METRIC_ATTENDANCE => '%',
            self::METRIC_RECITATION => ' سطر',
            self::METRIC_POINTS => ' نقطة',
            default => '',
        };
    }

    /**
     * صفوف الترتيب كاملةً، نازلةً بالقيمة — تأخذ منها الشاشة رأسها وذيلها.
     *
     * @return Collection<int, array{id: int, name: string, value: float}>
     */
    public function leaderboard(string $entity, string $metric, DateRange $range, ?Course $course): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        $rows = $entity === self::ENTITY_CIRCLES
            ? $this->forCircles($metric, $range, $course)
            : $this->forStudents($metric, $range, $course);

        return $rows->sortByDesc('value')->values();
    }

    /**
     * @return Collection<int, array{id: int, name: string, value: float}>
     */
    private function forCircles(string $metric, DateRange $range, Course $course): Collection
    {
        /** @var Collection<int, CourseCircle> $courseCircles */
        $courseCircles = $course->courseCircles()->with('circle')->get();

        if ($courseCircles->isEmpty()) {
            return new Collection;
        }

        $values = match ($metric) {
            self::METRIC_ATTENDANCE => $this->circleAttendanceRates($courseCircles, $range),
            self::METRIC_RECITATION => $this->sumBy(
                MemorizationLog::query()
                    ->whereIn('course_circle_id', $courseCircles->modelKeys())
                    ->whereBetween('date', [$range->from, $range->to])
                    ->groupBy('course_circle_id')
                    ->selectRaw('course_circle_id as grouping_key, SUM(new_lines) as aggregate')
            ),
            self::METRIC_POINTS => $courseCircles
                ->mapWithKeys(fn (CourseCircle $courseCircle) => [
                    $courseCircle->id => round((float) $this->points->forCircle($courseCircle, $range->from, $range->to)->sum('total'), 2),
                ])
                ->all(),
            default => $this->mannersByCircle($courseCircles, $range),
        };

        return $courseCircles->map(fn (CourseCircle $courseCircle) => [
            'id' => $courseCircle->id,
            'name' => $courseCircle->circle->name,
            'value' => round((float) ($values[$courseCircle->id] ?? 0), 2),
        ])->values();
    }

    /**
     * @return Collection<int, array{id: int, name: string, value: float}>
     */
    private function forStudents(string $metric, DateRange $range, Course $course): Collection
    {
        /** @var Collection<int, Student> $students */
        $students = Student::query()
            ->whereIn('id', $this->activeStudentIds($course))
            ->get(['id', 'first_name', 'father_name', 'family_name']);

        if ($students->isEmpty()) {
            return new Collection;
        }

        $ids = $students->modelKeys();

        $values = match ($metric) {
            self::METRIC_ATTENDANCE => $this->studentAttendanceRates($ids, $range),
            self::METRIC_RECITATION => $this->sumBy(
                MemorizationLog::query()
                    ->whereIn('student_id', $ids)
                    ->whereBetween('date', [$range->from, $range->to])
                    ->groupBy('student_id')
                    ->selectRaw('student_id as grouping_key, SUM(new_lines) as aggregate')
            ),
            self::METRIC_POINTS => $this->points
                ->forStudents($ids, $range->from, $range->to, $course->institute)
                ->map(fn (array $row) => $row['total'])
                ->all(),
            default => $this->mannersByStudent($ids, $range),
        };

        return $students->map(fn (Student $student) => [
            'id' => $student->id,
            'name' => $student->full_name,
            'value' => round((float) ($values[$student->id] ?? 0), 2),
        ])->values();
    }

    /**
     * @param  Collection<int, CourseCircle>  $courseCircles
     * @return array<int, float>
     */
    private function circleAttendanceRates(Collection $courseCircles, DateRange $range): array
    {
        return CircleDailyStat::query()
            ->whereIn('course_circle_id', $courseCircles->modelKeys())
            ->whereBetween('date', [$range->from, $range->to])
            ->get()
            ->groupBy('course_circle_id')
            ->map(fn (Collection $stats) => AttendanceRate::percent(
                (int) $stats->sum('present'),
                (int) $stats->sum('late'),
                (int) $stats->sum('excused'),
                (int) $stats->sum('total'),
            ))
            ->all();
    }

    /**
     * @param  array<int, int>  $studentIds
     * @return array<int, float>
     */
    private function studentAttendanceRates(array $studentIds, DateRange $range): array
    {
        $rows = $this->attendanceRows($studentIds, $range)
            ->groupBy('attendances.student_id', 'attendances.status')
            ->selectRaw('attendances.student_id as grouping_key, attendances.status, count(*) as aggregate')
            ->toBase()
            ->get();

        $counts = [];

        foreach ($rows as $row) {
            $counts[(int) $row->grouping_key][(string) $row->status] = (int) $row->aggregate;
        }

        return collect($counts)->map(fn (array $byStatus) => AttendanceRate::percent(
            $byStatus['present'] ?? 0,
            $byStatus['late'] ?? 0,
            $byStatus['excused'] ?? 0,
            array_sum($byStatus),
        ))->all();
    }

    /**
     * «الأدب» = عدد الملاحظات الإيجابية ناقص السلبية ضمن المدى.
     *
     * @param  Collection<int, CourseCircle>  $courseCircles
     * @return array<int, float>
     */
    private function mannersByCircle(Collection $courseCircles, DateRange $range): array
    {
        $rows = Attendance::query()
            ->join('attendance_sessions', 'attendance_sessions.id', '=', 'attendances.attendance_session_id')
            ->whereNull('attendances.deleted_at')
            ->whereIn('attendance_sessions.course_circle_id', $courseCircles->modelKeys())
            ->whereBetween('attendance_sessions.session_date', [$range->from, $range->to])
            ->whereNotNull('attendances.note_polarity')
            ->groupBy('attendance_sessions.course_circle_id', 'attendances.note_polarity')
            ->selectRaw('attendance_sessions.course_circle_id as grouping_key, attendances.note_polarity, count(*) as aggregate')
            ->toBase()
            ->get();

        return $this->netPolarity($rows);
    }

    /**
     * @param  array<int, int>  $studentIds
     * @return array<int, float>
     */
    private function mannersByStudent(array $studentIds, DateRange $range): array
    {
        $rows = $this->attendanceRows($studentIds, $range)
            ->whereNotNull('attendances.note_polarity')
            ->groupBy('attendances.student_id', 'attendances.note_polarity')
            ->selectRaw('attendances.student_id as grouping_key, attendances.note_polarity, count(*) as aggregate')
            ->toBase()
            ->get();

        return $this->netPolarity($rows);
    }

    /**
     * @param  Collection<int, object>  $rows  صفوف خام من toBase() لا نماذج
     * @return array<int, float>
     */
    private function netPolarity(Collection $rows): array
    {
        $net = [];

        foreach ($rows as $row) {
            $sign = $row->note_polarity === NotePolarity::Negative->value ? -1 : 1;
            $key = (int) $row->grouping_key;

            $net[$key] = ($net[$key] ?? 0) + $sign * (int) $row->aggregate;
        }

        return $net;
    }

    /**
     * @param  array<int, int>  $studentIds
     * @return Builder<Attendance>
     */
    private function attendanceRows(array $studentIds, DateRange $range): Builder
    {
        return Attendance::query()
            ->join('attendance_sessions', 'attendance_sessions.id', '=', 'attendances.attendance_session_id')
            ->whereNull('attendances.deleted_at')
            ->whereIn('attendances.student_id', $studentIds)
            ->whereBetween('attendance_sessions.session_date', [$range->from, $range->to]);
    }

    /**
     * @return array<int, int>
     */
    private function activeStudentIds(Course $course): array
    {
        return Enrollment::query()
            ->where('status', EnrollmentStatus::Active)
            ->whereIn('course_circle_id', $course->courseCircles()->select('id'))
            ->pluck('student_id')
            ->unique()
            ->values()
            ->all();
    }

    /**
     * صفوف التجميع تُقرأ خاماً — لا معنى لتركيب نموذج من صفٍّ فيه عمودان محسوبان.
     *
     * @param  Builder<covariant \Illuminate\Database\Eloquent\Model>  $query
     * @return array<int, float>
     */
    private function sumBy(Builder $query): array
    {
        return $query->toBase()->get()->mapWithKeys(fn ($row) => [(int) $row->grouping_key => (float) $row->aggregate])->all();
    }
}
