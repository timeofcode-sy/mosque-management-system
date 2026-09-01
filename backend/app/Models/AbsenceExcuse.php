<?php

namespace App\Models;

use App\Casts\DateOnly;
use App\Concerns\HasUuid;
use App\Enums\ExcuseStatus;
use Database\Factories\AbsenceExcuseFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * إذن غياب مسبق يقدّمه ولي الأمر فيُقترح حالة "مأذون" تلقائياً على شاشة تفقّد الأستاذ.
 */
#[Fillable([
    'student_id', 'from_date', 'to_date', 'reason', 'attachment_path',
    'submitted_by', 'status', 'reviewed_by', 'reviewed_at', 'review_note',
])]
class AbsenceExcuse extends Model
{
    /** @use HasFactory<AbsenceExcuseFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'from_date' => DateOnly::class,
            'to_date' => DateOnly::class,
            'status' => ExcuseStatus::class,
            'reviewed_at' => 'datetime',
        ];
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function submittedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'submitted_by');
    }

    public function reviewedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    /**
     * @param  Builder<AbsenceExcuse>  $query
     */
    public function scopeCovering(Builder $query, string $date): void
    {
        $query->where('status', ExcuseStatus::Approved)
            ->whereDate('from_date', '<=', $date)
            ->whereDate('to_date', '>=', $date);
    }
}
