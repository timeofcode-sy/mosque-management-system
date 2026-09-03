<?php

namespace App\Models;

use App\Concerns\HasUuid;
use Database\Factories\InstituteFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['name', 'short_name', 'logo_path', 'phone', 'email', 'address', 'settings', 'is_active'])]
class Institute extends Model
{
    /** @use HasFactory<InstituteFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'settings' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function courses(): HasMany
    {
        return $this->hasMany(Course::class);
    }

    public function circles(): HasMany
    {
        return $this->hasMany(Circle::class);
    }

    public function students(): HasMany
    {
        return $this->hasMany(Student::class);
    }

    public function teachers(): HasMany
    {
        return $this->hasMany(Teacher::class);
    }

    public function guardians(): HasMany
    {
        return $this->hasMany(Guardian::class);
    }

    public function personalTraits(): HasMany
    {
        return $this->hasMany(PersonalTrait::class);
    }

    public function curricula(): HasMany
    {
        return $this->hasMany(Curriculum::class);
    }

    public function customFields(): HasMany
    {
        return $this->hasMany(CustomField::class);
    }

    public function tags(): HasMany
    {
        return $this->hasMany(Tag::class);
    }

    public function announcements(): HasMany
    {
        return $this->hasMany(Announcement::class);
    }

    public function currentCourse(): ?Course
    {
        return $this->courses()->where('is_current', true)->first();
    }
}
