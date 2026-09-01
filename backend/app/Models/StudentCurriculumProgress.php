<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\ProgressStatus;
use Database\Factories\StudentCurriculumProgressFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * سجل محفوظات الطالب: حالة كل بند من بنود المناهج (جزء قرآني، متن، أربعون نبوية).
 */
#[Fillable([
    'student_id', 'curriculum_item_id', 'course_circle_id', 'status', 'percent',
    'score', 'started_on', 'completed_on', 'teacher_id', 'notes',
])]
class StudentCurriculumProgress extends Model
{
    /** @use HasFactory<StudentCurriculumProgressFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    protected $table = 'student_curriculum_progress';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => ProgressStatus::class,
            'percent' => 'integer',
            'score' => 'integer',
            'started_on' => 'date',
            'completed_on' => 'date',
        ];
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function curriculumItem(): BelongsTo
    {
        return $this->belongsTo(CurriculumItem::class);
    }

    public function courseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(Teacher::class);
    }
}
