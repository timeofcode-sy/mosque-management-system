<?php

namespace App\Models;

use App\Concerns\HasUuid;
use Database\Factories\GuardianFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * ولي أمر — الأب أو الأم أو غيرهما؛ صلة القرابة تُحفظ في جدول الربط guardian_student.
 */
#[Fillable([
    'institute_id', 'user_id', 'full_name', 'phone', 'alternate_phone',
    'occupation', 'national_id', 'address', 'is_alive', 'notes',
])]
class Guardian extends Model
{
    /** @use HasFactory<GuardianFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_alive' => 'boolean',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function students(): BelongsToMany
    {
        return $this->belongsToMany(Student::class)
            ->withPivot(['relation', 'is_primary', 'can_view_reports', 'can_submit_excuses'])
            ->withTimestamps();
    }
}
