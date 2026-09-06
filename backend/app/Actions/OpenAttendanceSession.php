<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\User;
use App\Support\SyncRecorder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * فتح جلسة تفقّد لحلقة في تاريخ محدّد — أو استرجاع الجلسة القائمة.
 *
 * الجلسة تُبذَر بصفٍّ لكل طالب مسجَّل في ذلك التاريخ حتى تفتح الشبكة جاهزة للضغط،
 * والطالب الذي يغطّيه إذن غياب مقبول يُقترح "مأذون" بدل "حاضر".
 */
class OpenAttendanceSession
{
    public function __construct(private readonly SyncRecorder $recorder) {}

    public function handle(CourseCircle $courseCircle, ?string $date = null, ?User $openedBy = null): AttendanceSession
    {
        $date = $date ?? Carbon::today()->toDateString();

        return DB::transaction(function () use ($courseCircle, $date, $openedBy): AttendanceSession {
            $session = AttendanceSession::firstOrCreate(
                ['course_circle_id' => $courseCircle->id, 'session_date' => $date],
                ['status' => SessionStatus::Draft, 'opened_by' => $openedBy?->id],
            );

            // الزرعُ ليس ملاحظةَ جهاز بل قيمةٌ افتراضية تنتظر من يؤكّدها، فيُسجَّل بلا
            // device_uuid — وعليه يميّزه ResolveAttendanceConflicts فلا يهدر تفقّداً حقيقياً
            // وصل متأخّراً دفاعاً عن قيمةٍ لم يقلها أحد.
            $this->recorder->withoutDevice(
                fn () => $this->seedAttendances($session, $this->enrollmentsOn($courseCircle, $date), $date, $openedBy),
            );

            return $session->refresh();
        });
    }

    /**
     * التسجيلات القائمة في ذلك التاريخ — بما فيها ما أُغلق لاحقاً بنقل أو انسحاب،
     * فالتفقّد الرجعي يجب أن يرى الحلقة كما كانت يومها.
     *
     * @return Collection<int, Enrollment>
     */
    public function enrollmentsOn(CourseCircle $courseCircle, string $date): Collection
    {
        return $courseCircle->enrollments()
            ->with('student')
            ->where(fn ($query) => $query->whereNull('enrolled_on')->orWhereDate('enrolled_on', '<=', $date))
            ->where(fn ($query) => $query->whereNull('left_on')->orWhereDate('left_on', '>=', $date))
            ->get()
            ->sortBy(fn (Enrollment $enrollment) => $enrollment->student->full_name)
            ->values();
    }

    /**
     * @param  Collection<int, Enrollment>  $enrollments
     */
    private function seedAttendances(AttendanceSession $session, Collection $enrollments, string $date, ?User $openedBy): void
    {
        $existing = $session->attendances()->pluck('student_id')->all();
        $excused = $this->excusedStudentIds($enrollments->pluck('student_id')->all(), $date);

        foreach ($enrollments as $enrollment) {
            if (in_array($enrollment->student_id, $existing, true)) {
                continue;
            }

            Attendance::create([
                'attendance_session_id' => $session->id,
                'student_id' => $enrollment->student_id,
                'enrollment_id' => $enrollment->id,
                'status' => in_array($enrollment->student_id, $excused, true)
                    ? AttendanceStatus::Excused
                    : AttendanceStatus::Present,
                'recorded_by' => $openedBy?->id,
                'recorded_at' => now(),
            ]);
        }
    }

    /**
     * @param  array<int, int>  $studentIds
     * @return array<int, int>
     */
    private function excusedStudentIds(array $studentIds, string $date): array
    {
        return AbsenceExcuse::query()
            ->covering($date)
            ->whereIn('student_id', $studentIds)
            ->pluck('student_id')
            ->all();
    }
}
