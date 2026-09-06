<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\GuardianRelation;
use App\Support\SyncScope;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * ربط ولي الأمر بالطالب مع صلة القرابة وصلاحيات المتابعة.
 */
#[Fillable(['guardian_id', 'student_id', 'relation', 'is_primary', 'can_view_reports', 'can_submit_excuses'])]
class GuardianStudent extends Model implements Syncable
{
    use HasUuid, RecordsSyncChanges;

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

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Student::class, $this->student_id);
    }
}
