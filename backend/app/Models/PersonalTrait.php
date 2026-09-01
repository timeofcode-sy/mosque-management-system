<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\TraitPolarity;
use Database\Factories\PersonalTraitFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/**
 * صفة شخصية أو سلوكية للطالب (هادئ، مبدع، خجول...). الاسم PersonalTrait لأن Trait كلمة محجوزة في PHP.
 */
#[Fillable(['institute_id', 'name', 'slug', 'polarity', 'color', 'sort_order', 'is_active'])]
class PersonalTrait extends Model
{
    /** @use HasFactory<PersonalTraitFactory> */
    use HasFactory, HasUuid;

    protected $table = 'traits';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'polarity' => TraitPolarity::class,
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function students(): BelongsToMany
    {
        return $this->belongsToMany(Student::class, 'student_trait', 'trait_id', 'student_id')
            ->withPivot(['note', 'noted_by'])
            ->withTimestamps();
    }
}
