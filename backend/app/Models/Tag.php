<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use Database\Factories\TagFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphToMany;

#[Fillable(['institute_id', 'name', 'slug', 'color'])]
class Tag extends Model implements Syncable
{
    /** @use HasFactory<TagFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges;

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function students(): MorphToMany
    {
        return $this->morphedByMany(Student::class, 'taggable');
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return $this->institute_id;
    }
}
