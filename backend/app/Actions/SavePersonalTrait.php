<?php

namespace App\Actions;

use App\Models\Institute;
use App\Models\PersonalTrait;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * يحفظ صفةً شخصية أو يحذفها — من شاشة «الصفات» في اللوحة ومن برنامج الإدارة.
 */
class SavePersonalTrait
{
    /**
     * @param  array{name: string, polarity: string, color?: ?string, sort_order?: int, is_active?: bool}  $attributes
     */
    public function handle(Institute $institute, array $attributes, ?PersonalTrait $existing = null): PersonalTrait
    {
        $payload = [
            'name' => $attributes['name'],
            'polarity' => $attributes['polarity'],
            'color' => $attributes['color'] ?? null,
            'sort_order' => (int) ($attributes['sort_order'] ?? 0),
            'is_active' => (bool) ($attributes['is_active'] ?? true),
            'institute_id' => $institute->id,
            'slug' => Str::slug($attributes['name']) ?: Str::random(8),
        ];

        if ($existing !== null) {
            $existing->update($payload);

            return $existing->refresh();
        }

        return PersonalTrait::create($payload);
    }

    /**
     * صفةٌ مسنَدةٌ إلى طلابٍ لا تُحذف: حذفُها يمحو أثرها من ملفّاتهم بلا علم.
     */
    public function delete(PersonalTrait $personalTrait): void
    {
        if ($personalTrait->students()->exists()) {
            throw new RuntimeException('لا يمكن حذف صفة مسنَدة إلى طلاب.');
        }

        $personalTrait->delete();
    }
}
