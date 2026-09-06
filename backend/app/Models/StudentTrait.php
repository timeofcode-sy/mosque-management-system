<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Support\SyncScope;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * إسناد صفة شخصية أو سلوكية لطالب، مع من رصدها وملاحظته.
 */
#[Fillable(['student_id', 'trait_id', 'noted_by', 'note'])]
class StudentTrait extends Model implements Syncable
{
    use HasUuid, RecordsSyncChanges;

    protected $table = 'student_trait';

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function personalTrait(): BelongsTo
    {
        return $this->belongsTo(PersonalTrait::class, 'trait_id');
    }

    public function notedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'noted_by');
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Student::class, $this->student_id);
    }
}
