<?php

namespace App\Actions;

use App\Models\Device;
use App\Models\SyncDevice;
use App\Models\User;

/**
 * تسجيل جهاز عند أول تشغيل للتطبيق أو أول دخول: يفتح له مؤشّر مزامنة (sync_devices)،
 * وإن أرسل fcm_token يسجَّل أيضاً في devices لاستقبال الإشعارات الفورية (مؤجَّلة للمرحلة 7).
 */
class RegisterDevice
{
    /**
     * @param  array{device_uuid: string, app: string, platform?: string|null, app_version?: string|null, fcm_token?: string|null}  $attributes
     */
    public function handle(User $user, array $attributes): SyncDevice
    {
        $syncDevice = SyncDevice::updateOrCreate(
            ['device_uuid' => $attributes['device_uuid']],
            [
                'user_id' => $user->id,
                'app' => $attributes['app'],
                'platform' => $attributes['platform'] ?? null,
                'app_version' => $attributes['app_version'] ?? null,
            ],
        );

        if (! blank($attributes['fcm_token'] ?? null)) {
            Device::updateOrCreate(
                ['user_id' => $user->id, 'app' => $attributes['app'], 'fcm_token' => $attributes['fcm_token']],
                ['platform' => $attributes['platform'] ?? null, 'last_seen_at' => now()],
            );
        }

        return $syncDevice;
    }
}
