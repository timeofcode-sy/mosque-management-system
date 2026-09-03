<?php

namespace App\Queries;

use App\Enums\AttendanceStatus;
use App\Models\Attendance;
use App\Models\CircleDailyStat;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\StudentCurriculumProgress;
use App\Models\StudentPoint;
use App\Support\AttendanceRate;
use App\Support\DateRange;
use App\Support\PointsSettings;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;

/**
 * قائمة المعاهد ولوحة مقارنتها — للمشرف الأعلى والمبرمج.
 *
 * ⚠️ كل استعلامات هذا الصنف **تتجاوز نطاق المعهد الحالي عمداً**، وهو الوحيد في
 * المشروع الذي يفعل ذلك. المشروع لا يستعمل global scopes (كل استعلام يفلتر
 * institute_id بيده)، فلا شيء يمنع التجاوز تقنياً — ولذلك بالضبط يلزم التنبيه:
 * لا يُنسخ هذا النمط إلى استعلام يجب أن يبقى محصوراً بمعهد واحد.
 *
 * ولذلك أيضاً تُبنى المجاميع باستعلامات مجمّعة تغطّي كل المعاهد دفعةً واحدة، لا
 * بحلقة على المعاهد: خمسة استعلامات مهما بلغ عددها.
 */
class InstituteAdminQuery
{
    /**
     * @return LengthAwarePaginator<int, Institute>
     */
    public function list(string $search = '', int $perPage = 20): LengthAwarePaginator
    {
        return Institute::query()
            ->withCount(['circles', 'students', 'teachers'])
            ->with(['courses' => fn ($query) => $query->where('is_current', true)])
            ->when($search !== '', fn ($query) => $query->where(
                fn ($inner) => $inner->where('name', 'like', "%{$search}%")
                    ->orWhere('short_name', 'like', "%{$search}%"),
            ))
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->paginate($perPage);
    }

    /**
     * لوحة المقارنة: صفٌّ لكل معهد ومجاميعُ فوقها.
     *
     * @return array{
     *     rows: Collection<int, array{institute: Institute, students: int, circles: int, teachers: int, sessions: int, rate: float, points: float}>,
     *     totals: array{institutes: int, students: int, circles: int, teachers: int, rate: float}
     * }
     */
    public function overview(DateRange $range): array
    {
        $institutes = Institute::query()
            ->withCount(['circles', 'students', 'teachers'])
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->get();

        $attendance = $this->attendanceByInstitute($range);
        $points = $this->pointsByInstitute($institutes, $range);

        $rows = $institutes->map(function (Institute $institute) use ($attendance, $points): array {
            $counts = $attendance[$institute->id] ?? ['present' => 0, 'late' => 0, 'excused' => 0, 'total' => 0, 'sessions' => 0];

            return [
                'institute' => $institute,
                'students' => (int) $institute->students_count,
                'circles' => (int) $institute->circles_count,
                'teachers' => (int) $institute->teachers_count,
                'sessions' => (int) $counts['sessions'],
                'rate' => AttendanceRate::of($counts),
                'points' => round((float) ($points[$institute->id] ?? 0.0), 2),
            ];
        });

        return [
            'rows' => $rows,
            'totals' => [
                'institutes' => $institutes->where('is_active', true)->count(),
                'students' => (int) $institutes->sum('students_count'),
                'circles' => (int) $institutes->sum('circles_count'),
                'teachers' => (int) $institutes->sum('teachers_count'),
                'rate' => AttendanceRate::of([
                    'present' => (int) collect($attendance)->sum('present'),
                    'late' => (int) collect($attendance)->sum('late'),
                    'excused' => (int) collect($attendance)->sum('excused'),
                    'total' => (int) collect($attendance)->sum('total'),
                ]),
            ],
        ];
    }

    /**
     * نسبة الحضور لكل معهد من الإحصاء اليومي المجمّع مسبقاً — استعلام واحد لكل المعاهد.
     *
     * @return array<int, array{present: int, late: int, excused: int, total: int, sessions: int}>
     */
    private function attendanceByInstitute(DateRange $range): array
    {
        $rows = CircleDailyStat::query()
            ->join('course_circles', 'course_circles.id', '=', 'circle_daily_stats.course_circle_id')
            ->join('courses', 'courses.id', '=', 'course_circles.course_id')
            ->whereBetween('circle_daily_stats.date', [$range->from, $range->to])
            ->groupBy('courses.institute_id')
            ->selectRaw('courses.institute_id, SUM(circle_daily_stats.present) as present, SUM(circle_daily_stats.late) as late, SUM(circle_daily_stats.excused) as excused, SUM(circle_daily_stats.total) as total, COUNT(*) as sessions')
            ->toBase()
            ->get();

        $counts = [];

        foreach ($rows as $row) {
            $counts[(int) $row->institute_id] = [
                'present' => (int) $row->present,
                'late' => (int) $row->late,
                'excused' => (int) $row->excused,
                'total' => (int) $row->total,
                'sessions' => (int) $row->sessions,
            ];
        }

        return $counts;
    }

    /**
     * مجموع نقاط كل معهد ضمن المدى: التسميع + بنود المناهج + التقديرية + الحضور المشتقّ.
     *
     * أربعة استعلامات مجمّعة مهما بلغ عدد المعاهد — ونقاط الحضور وحدها تحتاج إعدادات
     * كل معهد، فهي تُطبَّق على صفوف مجمّعة بـ (معهد، حالة) لا صفاً صفاً.
     *
     * @param  Collection<int, Institute>  $institutes
     * @return array<int, float>
     */
    private function pointsByInstitute(Collection $institutes, DateRange $range): array
    {
        $points = [];

        $add = function (array $rows) use (&$points): void {
            foreach ($rows as $instituteId => $value) {
                $points[(int) $instituteId] = ($points[(int) $instituteId] ?? 0.0) + (float) $value;
            }
        };

        $add(MemorizationLog::query()
            ->join('students', 'students.id', '=', 'memorization_logs.student_id')
            ->whereNull('memorization_logs.deleted_at')
            ->whereBetween('memorization_logs.date', [$range->from, $range->to])
            ->groupBy('students.institute_id')
            ->selectRaw('students.institute_id, SUM(memorization_logs.points) as aggregate')
            ->toBase()
            ->pluck('aggregate', 'institute_id')
            ->all());

        $add(StudentCurriculumProgress::query()
            ->join('students', 'students.id', '=', 'student_curriculum_progress.student_id')
            ->whereNull('student_curriculum_progress.deleted_at')
            ->whereBetween('student_curriculum_progress.achieved_on', [$range->from, $range->to])
            ->groupBy('students.institute_id')
            ->selectRaw('students.institute_id, SUM(student_curriculum_progress.points) as aggregate')
            ->toBase()
            ->pluck('aggregate', 'institute_id')
            ->all());

        $add(StudentPoint::query()
            ->join('students', 'students.id', '=', 'student_points.student_id')
            ->whereBetween('student_points.awarded_on', [$range->from, $range->to])
            ->groupBy('students.institute_id')
            ->selectRaw('students.institute_id, SUM(student_points.points) as aggregate')
            ->toBase()
            ->pluck('aggregate', 'institute_id')
            ->all());

        $settings = $institutes->mapWithKeys(fn (Institute $institute) => [$institute->id => PointsSettings::for($institute)]);

        $attendanceRows = Attendance::query()
            ->join('attendance_sessions', 'attendance_sessions.id', '=', 'attendances.attendance_session_id')
            ->join('students', 'students.id', '=', 'attendances.student_id')
            ->whereNull('attendances.deleted_at')
            ->whereBetween('attendance_sessions.session_date', [$range->from, $range->to])
            ->groupBy('students.institute_id', 'attendances.status')
            ->selectRaw('students.institute_id, attendances.status, COUNT(*) as aggregate')
            ->toBase()
            ->get();

        foreach ($attendanceRows as $row) {
            $status = AttendanceStatus::tryFrom((string) $row->status);
            $instituteSettings = $settings->get((int) $row->institute_id);

            if ($status === null || $instituteSettings === null) {
                continue;
            }

            $points[(int) $row->institute_id] = ($points[(int) $row->institute_id] ?? 0.0)
                + $instituteSettings->attendance($status) * (int) $row->aggregate;
        }

        return $points;
    }
}
