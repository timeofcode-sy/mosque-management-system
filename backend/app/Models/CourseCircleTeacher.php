<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\TeacherRole;
use Database\Factories\CourseCircleTeacherFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['course_circle_id', 'teacher_id', 'role', 'joined_on', 'left_on'])]
class CourseCircleTeacher extends Model
{
    /** @use HasFactory<CourseCircleTeacherFactory> */
    use HasFactory, HasUuid;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'role' => TeacherRole::class,
            'joined_on' => 'date',
            'left_on' => 'date',
        ];
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
