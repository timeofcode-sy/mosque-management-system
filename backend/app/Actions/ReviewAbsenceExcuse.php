<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\ExcuseStatus;
use App\Enums\SessionStatus;
use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\User;

/**
 * البتّ في إذن غياب مسبق.
 *
 * قبولُ إذنٍ يغطّي جلساتٍ لم تُقفل بعدُ يحوّل تفقّد الطالب فيها من "غائب" إلى "مأذون" —
 * فالإذن يصل غالباً بعد تسجيل الغياب، وتصحيحه يدوياً في كل جلسة عبء بلا فائدة.
 */
class ReviewAbsenceExcuse
{
    public function __construct(private RecalculateCircleStats $recalculate) {}

    public function handle(AbsenceExcuse $excuse, ExcuseStatus $decision, ?User $reviewedBy = null, ?string $note = null): AbsenceExcuse
    {
        $excuse->update([
            'status' => $decision,
            'reviewed_by' => $reviewedBy?->id,
            'reviewed_at' => now(),
            'review_note' => $note,
        ]);

        if ($decision === ExcuseStatus::Approved) {
            $this->applyToOpenSessions($excuse);
        }

        return $excuse->refresh();
    }

    private function applyToOpenSessions(AbsenceExcuse $excuse): void
    {
        $attendances = Attendance::query()
            ->where('student_id', $excuse->student_id)
            ->where('status', AttendanceStatus::Absent)
            ->whereHas('attendanceSession', fn ($query) => $query
                ->where('status', '!=', SessionStatus::Locked)
                ->whereDate('session_date', '>=', $excuse->from_date->toDateString())
                ->whereDate('session_date', '<=', $excuse->to_date->toDateString()))
            ->with('attendanceSession.courseCircle')
            ->get();

        foreach ($attendances as $attendance) {
            $attendance->update(['status' => AttendanceStatus::Excused]);

            $session = $attendance->attendanceSession;

            if ($session->status === SessionStatus::Completed) {
                $this->recalculate->handle(
                    $session->courseCircle->shift_id,
                    $session->session_date->toDateString(),
                );
            }
        }
    }
}
