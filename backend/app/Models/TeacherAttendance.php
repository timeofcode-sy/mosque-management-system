<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\AttendanceStatus;
use App\Support\SyncScope;
use Database\Factories\TeacherAttendanceFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'attendance_session_id', 'teacher_id', 'status',
    'late_minutes', 'note', 'recorded_by', 'recorded_at',
])]
class TeacherAttendance extends Model implements Syncable
{
    /** @use HasFactory<TeacherAttendanceFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => AttendanceStatus::class,
            'late_minutes' => 'integer',
            'recorded_at' => 'datetime',
        ];
    }

    public function attendanceSession(): BelongsTo
    {
        return $this->belongsTo(AttendanceSession::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(Teacher::class);
    }

    public function recordedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Teacher::class, $this->teacher_id);
    }
}
