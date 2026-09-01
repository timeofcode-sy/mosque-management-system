<?php

namespace App\Models;

use App\Concerns\HasUuid;
use Database\Factories\CustomFieldValueFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

#[Fillable(['custom_field_id', 'entity_type', 'entity_id', 'value'])]
class CustomFieldValue extends Model
{
    /** @use HasFactory<CustomFieldValueFactory> */
    use HasFactory, HasUuid;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'value' => 'array',
        ];
    }

    public function customField(): BelongsTo
    {
        return $this->belongsTo(CustomField::class);
    }

    public function entity(): MorphTo
    {
        return $this->morphTo();
    }
}
