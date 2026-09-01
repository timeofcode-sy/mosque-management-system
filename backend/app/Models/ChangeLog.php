<?php

namespace App\Models;

use App\Enums\SyncOperation;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * سجل التغييرات الذي يقرأ منه العملاء عبر sync/pull؛ المعرّف هو نفسه server_seq.
 */
#[Fillable(['table_name', 'row_uuid', 'operation', 'payload', 'scope_key', 'actor_user_id', 'device_uuid', 'op_uuid', 'created_at'])]
class ChangeLog extends Model
{
    protected $table = 'change_log';

    public const UPDATED_AT = null;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'operation' => SyncOperation::class,
            'payload' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
