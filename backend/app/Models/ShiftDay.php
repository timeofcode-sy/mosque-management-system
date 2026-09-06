<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Support\SyncScope;
use Database\Factories\ShiftDayFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['shift_id', 'weekday'])]
class ShiftDay extends Model implements Syncable
{
    /** @use HasFactory<ShiftDayFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'weekday' => 'integer',
        ];
    }

    public function shift(): BelongsTo
    {
        return $this->belongsTo(Shift::class);
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Shift::class, $this->shift_id);
    }
}
