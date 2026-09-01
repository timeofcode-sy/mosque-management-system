<?php

namespace App\Actions;

use App\Models\ChangeLog;
use App\Models\SyncDevice;
use App\Models\User;
use App\Support\ApiScope;
use Illuminate\Support\Collection;

/**
 * يعيد تغييرات change_log ضمن نطاق المستخدم منذ آخر معرّف سحبه، ويحدّث مؤشّر جهازه.
 *
 * النطاق الآن معهدٌ كامل (scope_key = institute:{uuid}) لكل الأدوار؛ تضييقه إلى حلقات
 * الأستاذ وحده مؤجَّل لِما بعد المرحلة 4 حين تُقاس فعلياً كلفة سحب معهدٍ كامل على جهاز أستاذ.
 */
class SyncPull
{
    private const int PAGE_SIZE = 500;

    /**
     * @return array{server_seq: int, changes: Collection<int, ChangeLog>}
     */
    public function handle(User $user, int $since, string $app, ?string $deviceUuid = null): array
    {
        $scopeKey = ApiScope::for($user)->scopeKey();

        $changes = ChangeLog::query()
            ->where('scope_key', $scopeKey)
            ->where('id', '>', $since)
            ->orderBy('id')
            ->limit(self::PAGE_SIZE)
            ->get();

        $serverSeq = $changes->max('id') ?? $since;

        if ($deviceUuid !== null) {
            SyncDevice::updateOrCreate(
                ['device_uuid' => $deviceUuid],
                ['user_id' => $user->id, 'app' => $app, 'last_pulled_seq' => $serverSeq, 'last_pulled_at' => now()],
            );
        }

        return ['server_seq' => $serverSeq, 'changes' => $changes];
    }
}
