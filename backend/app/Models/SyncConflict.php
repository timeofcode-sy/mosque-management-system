<?php

namespace App\Models;

use App\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * القيمة المُستبدَلة عند تعارض جهازين على نفس الصف — تُعرض للمشرف للمراجعة.
 */
#[Fillable(['institute_id', 'table_name', 'row_uuid', 'server_payload', 'client_payload', 'resolution', 'device_uuid', 'reviewed_by', 'resolved_at'])]
class SyncConflict extends Model
{
    use HasUuid;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'server_payload' => 'array',
            'client_payload' => 'array',
            'resolved_at' => 'datetime',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function reviewedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
