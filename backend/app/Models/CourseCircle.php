<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\EnrollmentStatus;
use App\Support\SyncScope;
use Database\Factories\CourseCircleFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * تشغيل حلقة ضمن دورة ودوام محدّدين — هنا يعيش التسجيل والتفقّد والإحصاء.
 */
#[Fillable(['course_id', 'circle_id', 'shift_id', 'room', 'capacity', 'status', 'notes'])]
class CourseCircle extends Model implements Syncable
{
    /** @use HasFactory<CourseCircleFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'capacity' => 'integer',
        ];
    }

    public function course(): BelongsTo
    {
        return $this->belongsTo(Course::class);
    }

    public function circle(): BelongsTo
    {
        return $this->belongsTo(Circle::class);
    }

    public function shift(): BelongsTo
    {
        return $this->belongsTo(Shift::class);
    }

    public function courseCircleTeachers(): HasMany
    {
        return $this->hasMany(CourseCircleTeacher::class);
    }

    public function teachers(): BelongsToMany
    {
        return $this->belongsToMany(Teacher::class, 'course_circle_teachers')
            ->withPivot(['role', 'joined_on', 'left_on'])
            ->withTimestamps();
    }

    public function enrollments(): HasMany
    {
        return $this->hasMany(Enrollment::class);
    }

    public function activeEnrollments(): HasMany
    {
        return $this->enrollments()->where('status', EnrollmentStatus::Active);
    }

    public function students(): BelongsToMany
    {
        return $this->belongsToMany(Student::class, 'enrollments')
            ->withPivot(['status', 'enrolled_on', 'left_on'])
            ->withTimestamps();
    }

    public function attendanceSessions(): HasMany
    {
        return $this->hasMany(AttendanceSession::class);
    }

    public function dailyStats(): HasMany
    {
        return $this->hasMany(CircleDailyStat::class);
    }

    public function cumulativeStats(): HasMany
    {
        return $this->hasMany(CircleCumulativeStat::class);
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Circle::class, $this->circle_id);
    }
}
