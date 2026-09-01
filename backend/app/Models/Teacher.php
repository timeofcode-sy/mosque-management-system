<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\TeacherStatus;
use Database\Factories\TeacherFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'institute_id', 'user_id', 'display_name', 'phone', 'national_id', 'birth_date',
    'specialization', 'qualification', 'photo_path', 'address', 'hired_on', 'status', 'notes',
])]
class Teacher extends Model
{
    /** @use HasFactory<TeacherFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'birth_date' => 'date',
            'hired_on' => 'date',
            'status' => TeacherStatus::class,
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function courseCircles(): BelongsToMany
    {
        return $this->belongsToMany(CourseCircle::class, 'course_circle_teachers')
            ->withPivot(['role', 'joined_on', 'left_on'])
            ->withTimestamps();
    }

    public function attendances(): HasMany
    {
        return $this->hasMany(TeacherAttendance::class);
    }

    public function memorizationLogs(): HasMany
    {
        return $this->hasMany(MemorizationLog::class);
    }

    public function customFieldValues(): MorphMany
    {
        return $this->morphMany(CustomFieldValue::class, 'entity');
    }
}
