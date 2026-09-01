<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\ReportScope;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * قالب نصّي بمتغيّرات مثل circle_name و absent_list — يُعاد استخدامه لاحقاً كقالب رسالة.
 */
#[Fillable(['institute_id', 'key', 'name', 'scope', 'body', 'is_active'])]
class ReportTemplate extends Model
{
    use HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'scope' => ReportScope::class,
            'is_active' => 'boolean',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }
}
