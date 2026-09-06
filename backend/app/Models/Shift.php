<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\Weekday;
use App\Support\SyncScope;
use Database\Factories\ShiftFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['course_id', 'name', 'starts_at', 'ends_at', 'sort_order', 'is_active'])]
class Shift extends Model implements Syncable
{
    /** @use HasFactory<ShiftFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function course(): BelongsTo
    {
        return $this->belongsTo(Course::class);
    }

    public function days(): HasMany
    {
        return $this->hasMany(ShiftDay::class);
    }

    public function courseCircles(): HasMany
    {
        return $this->hasMany(CourseCircle::class);
    }

    /**
     * أيام الدوام الثابتة أسبوعياً كأرقام (0 = الأحد).
     *
     * @return array<int, int>
     */
    public function weekdays(): array
    {
        return $this->days->pluck('weekday')->sort()->values()->all();
    }

    /**
     * أسماء أيام الدوام بالعربية، مرتّبة من الأحد.
     *
     * @return array<int, string>
     */
    public function weekdayLabels(): array
    {
        return array_map(fn (int $weekday): string => Weekday::from($weekday)->label(), $this->weekdays());
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Course::class, $this->course_id);
    }
}
