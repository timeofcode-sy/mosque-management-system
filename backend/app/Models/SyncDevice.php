<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'device_uuid', 'user_id', 'app', 'last_pulled_seq', 'last_pushed_at', 'last_pulled_at', 'app_version', 'platform',
    'app_build', 'device_type', 'manufacturer', 'brand', 'model', 'os_version', 'sdk_int', 'screen', 'locale',
    'memory_mb', 'is_physical',
])]
class SyncDevice extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'last_pulled_seq' => 'integer',
            'last_pushed_at' => 'datetime',
            'last_pulled_at' => 'datetime',
            'app_build' => 'integer',
            'sdk_int' => 'integer',
            'memory_mb' => 'integer',
            'is_physical' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
