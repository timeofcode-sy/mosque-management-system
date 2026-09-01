<?php

namespace App\Models;

use App\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['institute_id', 'type', 'params', 'file_path', 'status', 'generated_by', 'generated_at'])]
class ReportExport extends Model
{
    use HasUuid;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'params' => 'array',
            'generated_at' => 'datetime',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function generatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'generated_by');
    }
}
