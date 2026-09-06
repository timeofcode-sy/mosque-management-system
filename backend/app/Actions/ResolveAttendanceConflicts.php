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
 * change_log يحمل تعديلاً سابقاً عليه من جهاز آخر فعلاً — والزرعُ create لا update،
 * فيميّزه هذا الشرط وحده.
 *
 * 🔄 كان الفحص على مستوى **الجلسة** («هل دفع جهازٌ آخر تفقّداً لهذه الجلسة؟») لأن
 * change_log لم يكن يحمل يومها إلا صفَّ الجلسة. وصار على مستوى **صفّ الحضور** بعد أن
 * صار المراقب يسجّل كل صفّ يتغيّر: التعارض نزاعٌ على طالبٍ بعينه لا على الجلسة كلّها،
 * فجهازان يتفقّدان طالبين مختلفين في جلسة واحدة لم يعودا يُحسبان متنازعين.
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
        $contested = $this->rowsWrittenByAnotherDevice($existing->pluck('uuid')->all(), $deviceUuid);

        $accepted = [];

        foreach ($rows as $studentId => $row) {
            $incomingRecordedAt = isset($row['recorded_at']) ? Carbon::parse($row['recorded_at']) : now();
            $current = $existing->get($studentId);

            $isGenuineConflict = $current !== null
                && in_array($current->uuid, $contested, true)
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
     * صفوف الحضور التي عدّلها جهازٌ آخر فعلاً — استعلامٌ واحد للجلسة كلّها لا واحدٌ
     * لكل طالب.
     *
     * @param  array<int, string>  $rowUuids
     * @return array<int, string>
     */
    private function rowsWrittenByAnotherDevice(array $rowUuids, ?string $deviceUuid): array
    {
        if ($rowUuids === []) {
            return [];
        }

        $notMine = fn ($query) => $query->when(
            $deviceUuid !== null,
            fn ($q) => $q->where(fn ($inner) => $inner->whereNull('device_uuid')->orWhere('device_uuid', '!=', $deviceUuid)),
        );

        return ChangeLog::query()
            ->where('table_name', 'attendances')
            ->whereIn('row_uuid', $rowUuids)
            ->where(fn ($query) => $query
                // تعديلٌ: كتابةٌ حقيقية أياً كان مصدرها — اللوحة (بلا جهاز) أو جهاز آخر.
                ->where(fn ($q) => $q->where('operation', 'update')->where($notMine))
                // إنشاء: كتابةٌ حقيقية **فقط** إن حملت جهازاً — فالزرع عند فتح الجلسة
                // يُسجَّل بلا جهاز (OpenAttendanceSession)، وليس قيمةً رآها أحد.
                ->orWhere(fn ($q) => $q->where('operation', 'create')->whereNotNull('device_uuid')->where($notMine)))
            ->pluck('row_uuid')
            ->all();
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
