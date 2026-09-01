<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\SessionStatus;
use Database\Factories\AttendanceSessionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['course_circle_id', 'session_date', 'status', 'opened_by', 'taken_by', 'completed_at', 'notes'])]
class AttendanceSession extends Model
{
    /** @use HasFactory<AttendanceSessionFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'session_date' => 'date',
            'status' => SessionStatus::class,
            'completed_at' => 'datetime',
        ];
    }

    public function courseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class);
    }

    public function attendances(): HasMany
    {
        return $this->hasMany(Attendance::class);
    }

    public function teacherAttendances(): HasMany
    {
        return $this->hasMany(TeacherAttendance::class);
    }

    public function openedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'opened_by');
    }

    public function takenBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'taken_by');
    }

    /**
     * الجلسة المقفلة أو المكتملة لا تُعدَّل إلا بصلاحية attendance.amend.
     */
    public function isEditable(): bool
    {
        return $this->status === SessionStatus::Draft;
    }
}
