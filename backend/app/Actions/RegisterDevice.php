<?php

namespace App\Actions;

use App\Models\Device;
use App\Models\SyncDevice;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Validation\Rule;

/**
 * تسجيل جهاز عند أول تشغيل للتطبيق أو أول دخول: يفتح له مؤشّر مزامنة (sync_devices)،
 * وإن أرسل fcm_token يسجَّل أيضاً في devices لاستقبال الإشعارات الفورية (مؤجَّلة للمرحلة 7).
 */
class RegisterDevice
{
    /**
     * وصفُ الجهاز لإحصاءات المطوّر — كلُّه اختياري، فالنسخُ القديمة تسجّل بدونه.
     *
     * @return array<string, array<int, mixed>>
     */
    public static function detailRules(): array
    {
        return [
            'app_build' => ['nullable', 'integer', 'min:0'],
            'device_type' => ['nullable', Rule::in(['phone', 'tablet', 'desktop'])],
            'manufacturer' => ['nullable', 'string', 'max:64'],
            'brand' => ['nullable', 'string', 'max:64'],
            'model' => ['nullable', 'string', 'max:96'],
            'os_version' => ['nullable', 'string', 'max:64'],
            'sdk_int' => ['nullable', 'integer', 'min:0', 'max:1000'],
            'screen' => ['nullable', 'string', 'max:16'],
            'locale' => ['nullable', 'string', 'max:16'],
            'memory_mb' => ['nullable', 'integer', 'min:0'],
            'is_physical' => ['nullable', 'boolean'],
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes  device_uuid وapp مطلوبان، والباقي اختياري
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
                ...Arr::only($attributes, array_keys(self::detailRules())),
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
