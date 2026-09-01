<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\CourseStatus;
use Database\Factories\CourseFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['institute_id', 'name', 'starts_on', 'ends_on', 'status', 'is_current', 'notes'])]
class Course extends Model
{
    /** @use HasFactory<CourseFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'starts_on' => 'date',
            'ends_on' => 'date',
            'status' => CourseStatus::class,
            'is_current' => 'boolean',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function shifts(): HasMany
    {
        return $this->hasMany(Shift::class);
    }

    public function courseCircles(): HasMany
    {
        return $this->hasMany(CourseCircle::class);
    }

    public function transfers(): HasMany
    {
        return $this->hasMany(StudentTransfer::class);
    }

    /**
     * @param  Builder<Course>  $query
     */
    public function scopeCurrent(Builder $query): void
    {
        $query->where('is_current', true);
    }
}
