<?php

namespace App\Actions;

use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\ChangeLog;
use App\Models\SyncConflict;
use Illuminate\Support\Carbon;

/**
 * يفلتر صفوف تفقّد قادمة من جهاز أوف-لاين: الصفّ الذي كتبه جهازٌ آخر بتاريخ recorded_at
 * أحدث يفوز، والقيمة المرفوضة من الدفعة الحالية تُسجَّل في sync_conflicts ليراجعها المشرف.
 *
 * "نادرة جداً" بحكم قيد unique(session, student) — لا تقع إلا حين يأخذ جهازان نفس الجلسة
 * أوف-لاين في آن واحد، كأستاذ ومشرف يفتحان نفس الحلقة كلٌّ من جهازه.
 *
 * القيمة المزروعة تلقائياً عند فتح الجلسة (OpenAttendanceSession) ليست "كتابة" بالمعنى
 * الذي يستحق تعارضاً: لا جهاز حقيقي أنتجها. لذا لا يُعتبر الصفّ منافساً إلا إذا كان
 * change_log يحمل عملية attendance.take سابقة عليه من جهاز آخر فعلاً.
 */
class ResolveAttendanceConflicts
{
    /**
     * @param  array<int, array{status?: string, late_minutes?: int|string|null, note?: string|null, recorded_at?: string|null}>  $rows  مفهرسة بمعرّف الطالب
     * @return array<int, array{status?: string, late_minutes?: int|string|null, note?: string|null}>
     */
    public function handle(AttendanceSession $session, array $rows, ?string $deviceUuid): array
    {
        $existing = $session->attendances()->get()->keyBy('student_id');
        $anotherDeviceAlreadyTookThisSession = $this->wasPreviouslyTakenByAnotherDevice($session, $deviceUuid);

        $accepted = [];

        foreach ($rows as $studentId => $row) {
            $incomingRecordedAt = isset($row['recorded_at']) ? Carbon::parse($row['recorded_at']) : now();
            $current = $existing->get($studentId);

            $isGenuineConflict = $current !== null
                && $anotherDeviceAlreadyTookThisSession
                && $current->recorded_at !== null
                && $current->recorded_at->gt($incomingRecordedAt)
                && $current->status->value !== ($row['status'] ?? null);

            if ($isGenuineConflict) {
                $this->logConflict($current, $row, $deviceUuid);

                continue;
            }

            $accepted[$studentId] = $row;
        }

        return $accepted;
    }

    /**
     * هل سبق أن دفع جهازٌ آخر تفقّداً صريحاً لهذه الجلسة؟
     */
    private function wasPreviouslyTakenByAnotherDevice(AttendanceSession $session, ?string $deviceUuid): bool
    {
        return ChangeLog::query()
            ->where('table_name', 'attendance_sessions')
            ->where('row_uuid', $session->uuid)
            ->where('operation', 'update')
            ->when($deviceUuid !== null, fn ($query) => $query->where(fn ($q) => $q->whereNull('device_uuid')->orWhere('device_uuid', '!=', $deviceUuid)))
            ->exists();
    }

    /**
     * @param  array<string, mixed>  $incoming
     */
    private function logConflict(Attendance $serverRow, array $incoming, ?string $deviceUuid): void
    {
        SyncConflict::create([
            'table_name' => 'attendances',
            'row_uuid' => $serverRow->uuid,
            'server_payload' => $serverRow->toArray(),
            'client_payload' => $incoming,
            'resolution' => 'server_wins',
            'device_uuid' => $deviceUuid,
        ]);
    }
}
