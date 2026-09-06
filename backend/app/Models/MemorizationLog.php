<?php

namespace App\Models;

use App\Casts\DateOnly;
use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\MemorizationType;
use App\Enums\RecitationGrade;
use App\Support\SyncScope;
use Database\Factories\MemorizationLogFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * سجل يومي لما حفظه الطالب أو راجعه أو تلاه في الجلسة.
 */
#[Fillable([
    'student_id', 'course_circle_id', 'attendance_session_id', 'curriculum_item_id', 'date', 'type', 'grade',
    'from_surah', 'from_ayah', 'to_surah', 'to_ayah', 'pages', 'lines', 'new_lines', 'points', 'juz',
    'memorization_score', 'tajweed_score', 'mistakes_count', 'teacher_id', 'notes',
])]
class MemorizationLog extends Model implements Syncable
{
    /** @use HasFactory<MemorizationLogFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'date' => DateOnly::class,
            'type' => MemorizationType::class,
            'grade' => RecitationGrade::class,
            'from_surah' => 'integer',
            'from_ayah' => 'integer',
            'to_surah' => 'integer',
            'to_ayah' => 'integer',
            'pages' => 'decimal:2',
            'lines' => 'decimal:2',
            'new_lines' => 'decimal:2',
            'points' => 'decimal:2',
            'juz' => 'integer',
            'memorization_score' => 'integer',
            'tajweed_score' => 'integer',
            'mistakes_count' => 'integer',
        ];
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function courseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class);
    }

    public function attendanceSession(): BelongsTo
    {
        return $this->belongsTo(AttendanceSession::class);
    }

    public function curriculumItem(): BelongsTo
    {
        return $this->belongsTo(CurriculumItem::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(Teacher::class);
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Student::class, $this->student_id);
    }
}
