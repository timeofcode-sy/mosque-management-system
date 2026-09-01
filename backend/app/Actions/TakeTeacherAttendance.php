<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\TeacherAttendance;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * حضور الأساتذة في الجلسة نفسها.
 *
 * منفصل عن TakeAttendance لأن حضور الأستاذ لا يدخل في نسبة الحلقة ولا في ترتيبها —
 * خلطهما كان سيلوّث الإحصاء بصفٍّ ليس طالباً.
 */
class TakeTeacherAttendance
{
    /**
     * @param  array<int, array{status?: string, late_minutes?: int|string|null, note?: string|null}>  $rows  مفهرسة بمعرّف الأستاذ
     */
    public function handle(AttendanceSession $session, array $rows, ?User $recordedBy = null): AttendanceSession
    {
        if ($session->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        return DB::transaction(function () use ($session, $rows, $recordedBy): AttendanceSession {
            foreach ($rows as $teacherId => $row) {
                $status = AttendanceStatus::tryFrom((string) ($row['status'] ?? ''));

                if ($status === null) {
                    continue;
                }

                TeacherAttendance::updateOrCreate(
                    ['attendance_session_id' => $session->id, 'teacher_id' => (int) $teacherId],
                    [
                        'status' => $status,
                        'late_minutes' => $status === AttendanceStatus::Late ? (int) ($row['late_minutes'] ?? 0) : null,
                        'note' => blank($row['note'] ?? null) ? null : $row['note'],
                        'recorded_by' => $recordedBy?->id,
                        'recorded_at' => now(),
                    ],
                );
            }

            return $session->refresh();
        });
    }
}
