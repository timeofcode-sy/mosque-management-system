<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Enums\CurriculumType;
use Database\Factories\CurriculumFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * منهج علمي: القرآن الكريم، الحديث الشريف، المتون العلمية، أو منهج يضيفه المعهد.
 */
#[Fillable(['institute_id', 'name', 'slug', 'type', 'description', 'sort_order', 'is_active'])]
class Curriculum extends Model implements Syncable
{
    /** @use HasFactory<CurriculumFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    protected $table = 'curricula';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'type' => CurriculumType::class,
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(CurriculumItem::class)->orderBy('sort_order');
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return $this->institute_id;
    }
}
