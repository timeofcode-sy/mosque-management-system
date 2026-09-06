<?php

namespace App\Models;

use App\Casts\DateOnly;
use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\EvaluationPeriod;
use App\Support\SyncScope;
use Database\Factories\EvaluationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'student_id', 'course_circle_id', 'period', 'period_start', 'period_end',
    'behavior', 'commitment', 'memorization', 'tajweed', 'total', 'teacher_id', 'notes',
])]
class Evaluation extends Model implements Syncable
{
    /** @use HasFactory<EvaluationFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'period' => EvaluationPeriod::class,
            'period_start' => DateOnly::class,
            'period_end' => DateOnly::class,
            'behavior' => 'integer',
            'commitment' => 'integer',
            'memorization' => 'integer',
            'tajweed' => 'integer',
            'total' => 'integer',
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
