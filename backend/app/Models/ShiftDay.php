<?php

namespace App\Models;

use App\Concerns\HasUuid;
use Database\Factories\ShiftDayFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['shift_id', 'weekday'])]
class ShiftDay extends Model
{
    /** @use HasFactory<ShiftDayFactory> */
    use HasFactory, HasUuid;

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
}
