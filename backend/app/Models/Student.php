<?php

namespace App\Models;

use App\Casts\DateOnly;
use App\Concerns\HasUuid;
use App\Enums\EnrollmentStatus;
use App\Enums\Gender;
use App\Enums\GuardianRelation;
use App\Enums\StudentStatus;
use Database\Factories\StudentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\Relations\MorphToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'institute_id', 'user_id',
    'registration_no', 'registration_date', 'registration_date_hijri', 'photo_path',
    'first_name', 'father_name', 'family_name', 'birth_date', 'birth_place', 'gender',
    'national_id', 'grade_level', 'student_job', 'phone', 'permanent_address', 'current_address',
    'family_members_count', 'student_health_status', 'family_health_status',
    'status', 'notes',
])]
class Student extends Model
{
    /** @use HasFactory<StudentFactory> */
    use HasFactory, HasUuid, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'registration_date' => DateOnly::class,
            'birth_date' => DateOnly::class,
            'gender' => Gender::class,
            'status' => StudentStatus::class,
            'family_members_count' => 'integer',
        ];
    }

    /**
     * الاسم الثلاثي كما يُعرض في البطاقة والتقارير.
     */
    protected function fullName(): Attribute
    {
        return Attribute::get(fn (): string => trim("{$this->first_name} {$this->father_name} {$this->family_name}"));
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function guardians(): BelongsToMany
    {
        return $this->belongsToMany(Guardian::class)
            ->withPivot(['relation', 'is_primary', 'can_view_reports', 'can_submit_excuses'])
            ->withTimestamps();
    }

    public function father(): ?Guardian
    {
        return $this->guardians->firstWhere('pivot.relation', GuardianRelation::Father->value);
    }

    public function mother(): ?Guardian
    {
        return $this->guardians->firstWhere('pivot.relation', GuardianRelation::Mother->value);
    }

    public function personalTraits(): BelongsToMany
    {
        return $this->belongsToMany(PersonalTrait::class, 'student_trait', 'student_id', 'trait_id')
            ->withPivot(['note', 'noted_by'])
            ->withTimestamps();
    }

    public function enrollments(): HasMany
    {
        return $this->hasMany(Enrollment::class);
    }

    public function activeEnrollment(): ?Enrollment
    {
        return $this->enrollments()->where('status', EnrollmentStatus::Active)->latest('enrolled_on')->first();
    }

    public function attendances(): HasMany
    {
        return $this->hasMany(Attendance::class);
    }

    public function transfers(): HasMany
    {
        return $this->hasMany(StudentTransfer::class);
    }

    public function absenceExcuses(): HasMany
    {
        return $this->hasMany(AbsenceExcuse::class);
    }

    public function curriculumProgress(): HasMany
    {
        return $this->hasMany(StudentCurriculumProgress::class);
    }

    public function memorizationLogs(): HasMany
    {
        return $this->hasMany(MemorizationLog::class);
    }

    public function points(): HasMany
    {
        return $this->hasMany(StudentPoint::class);
    }

    public function evaluations(): HasMany
    {
        return $this->hasMany(Evaluation::class);
    }

    public function customFieldValues(): MorphMany
    {
        return $this->morphMany(CustomFieldValue::class, 'entity');
    }

    public function tags(): MorphToMany
    {
        return $this->morphToMany(Tag::class, 'taggable');
    }
}
