<?php

namespace App\Models;

use App\Casts\DateOnly;
use App\Concerns\HasUuid;
use Database\Factories\StudentTransferFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'student_id', 'course_id', 'from_course_circle_id', 'to_course_circle_id',
    'transferred_on', 'reason', 'performed_by',
])]
class StudentTransfer extends Model
{
    /** @use HasFactory<StudentTransferFactory> */
    use HasFactory, HasUuid;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'transferred_on' => DateOnly::class,
        ];
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function course(): BelongsTo
    {
        return $this->belongsTo(Course::class);
    }

    public function fromCourseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class, 'from_course_circle_id');
    }

    public function toCourseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class, 'to_course_circle_id');
    }

    public function performedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }
}
