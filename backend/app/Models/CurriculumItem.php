<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Support\SyncScope;
use Database\Factories\CurriculumItemFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * بند ضمن منهج: جزء من الثلاثين، أو متن كالبيقونية، أو الأربعون النبوية.
 */
#[Fillable(['curriculum_id', 'name', 'code', 'sort_order', 'meta', 'is_active'])]
class CurriculumItem extends Model implements Syncable
{
    /** @use HasFactory<CurriculumItemFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'meta' => 'array',
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function curriculum(): BelongsTo
    {
        return $this->belongsTo(Curriculum::class);
    }

    public function progress(): HasMany
    {
        return $this->hasMany(StudentCurriculumProgress::class);
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(Curriculum::class, $this->curriculum_id);
    }
}
