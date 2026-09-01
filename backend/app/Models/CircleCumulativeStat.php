<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * الإحصاء التراكمي للحلقة منذ بداية الدورة، مع ترتيبها الكلي بين حلقات الدوام.
 */
#[Fillable(['course_circle_id', 'as_of_date', 'sessions_count', 'present', 'absent', 'late', 'excused', 'total', 'attendance_rate', 'overall_rank_in_shift'])]
class CircleCumulativeStat extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'as_of_date' => 'date',
            'sessions_count' => 'integer',
            'present' => 'integer',
            'absent' => 'integer',
            'late' => 'integer',
            'excused' => 'integer',
            'total' => 'integer',
            'attendance_rate' => 'decimal:2',
            'overall_rank_in_shift' => 'integer',
        ];
    }

    public function courseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class);
    }
}
