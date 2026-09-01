<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\GuardianRelation;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * ربط ولي الأمر بالطالب مع صلة القرابة وصلاحيات المتابعة.
 */
#[Fillable(['guardian_id', 'student_id', 'relation', 'is_primary', 'can_view_reports', 'can_submit_excuses'])]
class GuardianStudent extends Model
{
    use HasUuid;

    protected $table = 'guardian_student';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'relation' => GuardianRelation::class,
            'is_primary' => 'boolean',
            'can_view_reports' => 'boolean',
            'can_submit_excuses' => 'boolean',
        ];
    }

    public function guardian(): BelongsTo
    {
        return $this->belongsTo(Guardian::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }
}
