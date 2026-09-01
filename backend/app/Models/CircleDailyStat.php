<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * إحصاء اليوم الواحد للحلقة، مع ترتيبها بين حلقات نفس الدوام في ذلك اليوم.
 */
#[Fillable(['course_circle_id', 'date', 'present', 'absent', 'late', 'excused', 'total', 'attendance_rate', 'daily_rank_in_shift'])]
class CircleDailyStat extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'date' => 'date',
            'present' => 'integer',
            'absent' => 'integer',
            'late' => 'integer',
            'excused' => 'integer',
            'total' => 'integer',
            'attendance_rate' => 'decimal:2',
            'daily_rank_in_shift' => 'integer',
        ];
    }

    public function courseCircle(): BelongsTo
    {
        return $this->belongsTo(CourseCircle::class);
    }
}
