<?php

namespace App\Actions;

use App\Enums\SyncOperation;
use App\Models\ChangeLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * يسجّل عملية كتابة واحدة في change_log — المصدر الذي تقرأ منه تطبيقات فلاتر عبر sync/pull.
 *
 * يُستدعى من نهاية كل Action يكتب صفاً في جدول يحمل uuid، حتى تظهر كتابات اللوحة نفسها
 * لتطبيق الأستاذ أوف-لاين. عمليات الدفع من العميل (SyncPush) تمرّر op_uuid الخاص بها؛
 * عمليات اللوحة تتركه فارغاً فيُنشئ الخادم واحداً حتى يبقى القيد unique ذا معنى.
 */
class RecordChange
{
    public function handle(
        Model $model,
        SyncOperation $operation,
        string $scopeKey,
        ?User $actor = null,
        ?string $deviceUuid = null,
        ?string $opUuid = null,
    ): ChangeLog {
        return ChangeLog::create([
            'table_name' => $model->getTable(),
            'row_uuid' => $model->getAttribute('uuid'),
            'operation' => $operation,
            'payload' => $operation === SyncOperation::Delete ? null : $model->toArray(),
            'scope_key' => $scopeKey,
            'actor_user_id' => $actor?->id,
            'device_uuid' => $deviceUuid,
            'op_uuid' => $opUuid ?? (string) Str::uuid7(),
        ]);
    }
}
