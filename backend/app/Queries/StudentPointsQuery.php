<?php

namespace App\Queries;

use App\Enums\AttendanceStatus;
use App\Enums\CurriculumType;
use App\Models\Attendance;
use App\Models\CourseCircle;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\StudentPoint;
use App\Support\PointsSettings;
use Illuminate\Support\Collection;

/**
 * مجاميع نقاط الطلاب ضمن مدى تواريخ، مقسّمة على مصادرها.
 *
 * النسخة المجمّعة forCircle() موجودة لأن تقرير الحلقة يحتاج كل طلابها: ثلاثة استعلامات
 * groupBy بدل استدعاء CalculateStudentPoints مرّةً لكل طالب.
 */
class StudentPointsQuery
{
    /**
     * الشكل الصفريّ لمجموع نقاط طالب — مرجعٌ واحد يمنع اختلاف المفاتيح بين المستدعين.
     */
    public const EMPTY = [
        'quran' => 0.0, 'hadith' => 0.0, 'mutun' => 0.0,
        'attendance' => 0.0, 'manual' => 0.0, 'total' => 0.0,
    ];

    /**
     * @param  array<int, int>  $studentIds
     * @return Collection<int, array{quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}>
     */
    public function forStudents(array $studentIds, string $from, string $to, ?Institute $institute = null): Collection
    {
        if ($studentIds === []) {
            return new Collection;
        }

        $settings = PointsSettings::for($institute);

        $memorization = $this->memorizationPoints($studentIds, $from, $to);
        $progress = $this->curriculumProgressPoints($studentIds, $from, $to);
        $attendance = $this->attendancePoints($studentIds, $from, $to, $settings);
        $manual = $this->manualPoints($studentIds, $from, $to);

        $sourceOf = fn (array $bag, int $studentId, CurriculumType $type): float => (float) ($bag[$studentId][$type->value] ?? 0.0);

        return collect($studentIds)->mapWithKeys(function (int $studentId) use ($memorization, $progress, $attendance, $manual, $sourceOf): array {
            $totals = [
                'quran' => $sourceOf($memorization, $studentId, CurriculumType::Quran)
                    + $sourceOf($progress, $studentId, CurriculumType::Quran),
                'hadith' => $sourceOf($memorization, $studentId, CurriculumType::Hadith)
                    + $sourceOf($progress, $studentId, CurriculumType::Hadith),
                'mutun' => $sourceOf($memorization, $studentId, CurriculumType::Mutun)
                    + $sourceOf($progress, $studentId, CurriculumType::Mutun),
                'attendance' => (float) ($attendance[$studentId] ?? 0.0),
                'manual' => (float) ($manual[$studentId] ?? 0.0),
            ];

            return [$studentId => [...$totals, 'total' => round(array_sum($totals), 2)]];
        });
    }

    /**
     * @return Collection<int, array{quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}>
     */
    public function forCircle(CourseCircle $courseCircle, string $from, string $to): Collection
    {
        $studentIds = $courseCircle->enrollments()->pluck('student_id')->unique()->values()->all();

        return $this->forStudents($studentIds, $from, $to, $courseCircle->circle->institute);
    }

    /**
     * @return array{quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}
     */
    public function forStudent(Student $student, string $from, string $to): array
    {
        return $this->forStudents([$student->id], $from, $to, $student->institute)->get($student->id) ?? self::EMPTY;
    }

    /**
     * نقاط التسميع مقسّمة على نوع المنهج — والسجلّ بلا بند منهج يُحسب قرآناً،
     * فالتسميع في الجلسة قرآنيّ بطبعه.
     *
     * @param  array<int, int>  $studentIds
     * @return array<int, array<string, float>>
     */
    private function memorizationPoints(array $studentIds, string $from, string $to): array
    {
        $rows = MemorizationLog::query()
            ->leftJoin('curriculum_items', 'curriculum_items.id', '=', 'memorization_logs.curriculum_item_id')
            ->leftJoin('curricula', 'curricula.id', '=', 'curriculum_items.curriculum_id')
            ->whereNull('memorization_logs.deleted_at')
            ->whereIn('memorization_logs.student_id', $studentIds)
            ->whereBetween('memorization_logs.date', [$from, $to])
            ->groupBy('memorization_logs.student_id', 'curricula.type')
            ->selectRaw('memorization_logs.student_id, curricula.type as curriculum_type, SUM(memorization_logs.points) as aggregate')
            ->toBase()
            ->get();

        $points = [];

        foreach ($rows as $row) {
            $type = $row->curriculum_type ?: CurriculumType::Quran->value;
            $points[(int) $row->student_id][$type] = ($points[(int) $row->student_id][$type] ?? 0.0) + (float) $row->aggregate;
        }

        return $points;
    }

    /**
     * نقاط بنود المناهج المحرَزة (الحديث والمتون) — مصدرها شاشة تقدّم المناهج في ملف
     * الطالب، لا الجلسة: إنجاز متنٍ حدثٌ يمتدّ أسابيع لا سطراً يُسمَّع في حلقة.
     *
     * نقاط القرآن هنا تبقى صفراً عملياً لأن أجزاءه تُحتسب بالتسميع لا بنسبة البند.
     *
     * @param  array<int, int>  $studentIds
     * @return array<int, array<string, float>>
     */
    private function curriculumProgressPoints(array $studentIds, string $from, string $to): array
    {
        $rows = StudentCurriculumProgress::query()
            ->join('curriculum_items', 'curriculum_items.id', '=', 'student_curriculum_progress.curriculum_item_id')
            ->join('curricula', 'curricula.id', '=', 'curriculum_items.curriculum_id')
            ->whereNull('student_curriculum_progress.deleted_at')
            ->whereIn('student_curriculum_progress.student_id', $studentIds)
            ->whereBetween('student_curriculum_progress.achieved_on', [$from, $to])
            ->groupBy('student_curriculum_progress.student_id', 'curricula.type')
            ->selectRaw('student_curriculum_progress.student_id, curricula.type as curriculum_type, SUM(student_curriculum_progress.points) as aggregate')
            ->toBase()
            ->get();

        $points = [];

        foreach ($rows as $row) {
            $points[(int) $row->student_id][(string) $row->curriculum_type] = (float) $row->aggregate;
        }

        return $points;
    }

    /**
     * نقاط الحضور مشتقّة لا مخزَّنة: صفوف الحضور تتغيّر بالتعديل، وتخزين نقاطها
     * يخلق مصدرَي حقيقة.
     *
     * الصفوف تُقرأ خاماً بـ toBase(): تركيبُ نماذج Eloquent يحوّل status إلى enum،
     * وصفُّ تجميعٍ ليس نموذجاً أصلاً.
     *
     * @param  array<int, int>  $studentIds
     * @return array<int, float>
     */
    private function attendancePoints(array $studentIds, string $from, string $to, PointsSettings $settings): array
    {
        $rows = Attendance::query()
            ->join('attendance_sessions', 'attendance_sessions.id', '=', 'attendances.attendance_session_id')
            ->whereNull('attendances.deleted_at')
            ->whereIn('attendances.student_id', $studentIds)
            ->whereBetween('attendance_sessions.session_date', [$from, $to])
            ->groupBy('attendances.student_id', 'attendances.status')
            ->selectRaw('attendances.student_id, attendances.status, count(*) as aggregate')
            ->toBase()
            ->get();

        $points = [];

        foreach ($rows as $row) {
            $status = AttendanceStatus::tryFrom((string) $row->status);

            if ($status === null) {
                continue;
            }

            $studentId = (int) $row->student_id;
            $points[$studentId] = ($points[$studentId] ?? 0.0) + $settings->attendance($status) * (int) $row->aggregate;
        }

        return $points;
    }

    /**
     * @param  array<int, int>  $studentIds
     * @return array<int, float>
     */
    private function manualPoints(array $studentIds, string $from, string $to): array
    {
        return StudentPoint::query()
            ->whereIn('student_id', $studentIds)
            ->whereBetween('awarded_on', [$from, $to])
            ->groupBy('student_id')
            ->selectRaw('student_id, SUM(points) as aggregate')
            ->toBase()
            ->pluck('aggregate', 'student_id')
            ->map(fn ($value) => (float) $value)
            ->all();
    }
}
