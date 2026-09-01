<?php

namespace App\Models;

use App\Concerns\HasUuid;
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
class CurriculumItem extends Model
{
    /** @use HasFactory<CurriculumItemFactory> */
    use HasFactory, HasUuid;

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
}
