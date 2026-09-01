<?php

namespace App\Models;

use App\Casts\DateOnly;
use App\Concerns\HasUuid;
use App\Enums\MemorizationType;
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
    'student_id', 'course_circle_id', 'attendance_session_id', 'curriculum_item_id', 'date', 'type',
    'from_surah', 'from_ayah', 'to_surah', 'to_ayah', 'pages',
    'memorization_score', 'tajweed_score', 'mistakes_count', 'teacher_id', 'notes',
])]
class MemorizationLog extends Model
{
    /** @use HasFactory<MemorizationLogFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'date' => DateOnly::class,
            'type' => MemorizationType::class,
            'from_surah' => 'integer',
            'from_ayah' => 'integer',
            'to_surah' => 'integer',
            'to_ayah' => 'integer',
            'pages' => 'decimal:2',
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
}
