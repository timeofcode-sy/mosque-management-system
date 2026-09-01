<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * كتابة حالات التفقّد لجلسة قائمة.
 *
 * الجلسة المقفلة لا تُعدَّل إطلاقاً. والمكتملة لا تُعدَّل إلا بتعديل صريح ($amend)
 * تحرسه الصلاحية attendance.amend في الواجهة — فالتصحيح الرجعي فعلٌ مقصود لا سهو.
 */
class TakeAttendance
{
    /**
     * @param  array<int, array{status?: string, late_minutes?: int|string|null, note?: string|null, recorded_at?: string|null}>  $rows  مفهرسة بمعرّف الطالب؛ recorded_at اختياري يستعمله الدفع أوف-لاين ليبقى زمن الحدث الحقيقي كما وقع على الجهاز، لا وقت وصوله للخادم
     */
    public function handle(AttendanceSession $session, array $rows, ?User $recordedBy = null, bool $amend = false): AttendanceSession
    {
        $this->guard($session, $amend);

        return DB::transaction(function () use ($session, $rows, $recordedBy): AttendanceSession {
            $enrollmentIds = $session->attendances()->pluck('enrollment_id', 'student_id');

            foreach ($rows as $studentId => $row) {
                $status = AttendanceStatus::tryFrom((string) ($row['status'] ?? ''));

                if ($status === null) {
                    continue;
                }

                Attendance::updateOrCreate(
                    ['attendance_session_id' => $session->id, 'student_id' => (int) $studentId],
                    [
                        'enrollment_id' => $enrollmentIds[(int) $studentId] ?? null,
                        'status' => $status,
                        'late_minutes' => $status === AttendanceStatus::Late ? (int) ($row['late_minutes'] ?? 0) : null,
                        'note' => blank($row['note'] ?? null) ? null : $row['note'],
                        'recorded_by' => $recordedBy?->id,
                        'recorded_at' => blank($row['recorded_at'] ?? null) ? now() : $row['recorded_at'],
                    ],
                );
            }

            return $session->refresh();
        });
    }

    private function guard(AttendanceSession $session, bool $amend): void
    {
        if ($session->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        if ($session->status === SessionStatus::Completed && ! $amend) {
            throw new RuntimeException('الجلسة مكتملة — أعد فتحها قبل التعديل.');
        }
    }
}
