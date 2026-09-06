<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Support\SyncScope;
use Database\Factories\CustomFieldValueFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

#[Fillable(['custom_field_id', 'entity_type', 'entity_id', 'value'])]
class CustomFieldValue extends Model implements Syncable
{
    /** @use HasFactory<CustomFieldValueFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges;

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

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return SyncScope::via(CustomField::class, $this->custom_field_id);
    }
}
