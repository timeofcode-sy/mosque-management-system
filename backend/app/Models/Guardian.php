<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Concerns\RecordsSyncChanges;
use App\Contracts\Syncable;
use App\Observers\GuardianObserver;
use Database\Factories\GuardianFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * ولي أمر — الأب أو الأم أو غيرهما؛ صلة القرابة تُحفظ في جدول الربط guardian_student.
 *
 * الاسم بقسمين: first_name (الاسم) وfamily_name (الكنية). full_name يُركَّب منهما عند
 * الحفظ ويبقى عموداً لأن القوائم وحسابات الدخول ومطابقة الإخوة تقرؤه.
 */
#[Fillable([
    'institute_id', 'user_id', 'full_name', 'first_name', 'family_name', 'phone', 'alternate_phone',
    'occupation', 'national_id', 'address', 'is_alive', 'notes',
])]
#[ObservedBy(GuardianObserver::class)]
class Guardian extends Model implements Syncable
{
    /** @use HasFactory<GuardianFactory> */
    use HasFactory, HasUuid, RecordsSyncChanges, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_alive' => 'boolean',
        ];
    }

    /**
     * ما تغيّر هو الأصل: قسما الاسم إن تغيّرا يركّبان الاسم الكامل، والاسم الكامل وحده
     * (عميلٌ أقدم أو إدراجٌ قديم) يُقسم إليهما — فلا يبقى قسمٌ قديم يناقض اسماً جديداً.
     */
    protected static function booted(): void
    {
        static::saving(function (Guardian $guardian): void {
            if ($guardian->isDirty(['first_name', 'family_name']) && (filled($guardian->first_name) || filled($guardian->family_name))) {
                $guardian->first_name = self::composeName($guardian->first_name) ?: null;
                $guardian->family_name = self::composeName($guardian->family_name) ?: null;
                $guardian->full_name = self::composeName($guardian->first_name, $guardian->family_name);
            } elseif ($guardian->isDirty('full_name')) {
                [$guardian->first_name, $guardian->family_name] = self::splitName($guardian->full_name);
            }
        });
    }

    /**
     * يضمّ أجزاء الاسم بفراغٍ واحد ويُسقط الفارغ منها.
     */
    public static function composeName(?string ...$parts): string
    {
        return trim((string) preg_replace('/\s+/u', ' ', implode(' ', $parts)));
    }

    /**
     * الاسم الكامل بقسمين حين لا يُعرف غيره: الكلمة الأولى اسم والباقي كنية.
     *
     * @return array{0: ?string, 1: ?string}
     */
    public static function splitName(?string $fullName): array
    {
        $parts = explode(' ', self::composeName($fullName), 2);

        return [$parts[0] ?: null, $parts[1] ?? null];
    }

    public function institute(): BelongsTo
    {
        return $this->belongsTo(Institute::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function students(): BelongsToMany
    {
        return $this->belongsToMany(Student::class)
            ->withPivot(['relation', 'is_primary', 'can_view_reports', 'can_submit_excuses'])
            ->withTimestamps();
    }

    /**
     * @see Syncable
     */
    public function syncInstituteId(): ?int
    {
        return $this->institute_id;
    }
}
