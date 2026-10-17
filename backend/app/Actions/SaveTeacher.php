<?php

namespace App\Actions;

use App\Enums\TeacherStatus;
use App\Models\Institute;
use App\Models\Teacher;
use Illuminate\Validation\Rule;

/**
 * يحفظ أستاذاً — من شاشة «الأساتذة» في اللوحة ومن برنامج الإدارة (`/admin/teachers`).
 *
 * والحسابُ يولَّد مع السجلّ في `TeacherObserver`، فلا شيءَ هنا عنه.
 */
class SaveTeacher
{
    /**
     * قواعدُ الاستمارة نفسُها في اللوحة والـAPI.
     *
     * @return array<string, array<int, mixed>>
     */
    public static function rules(): array
    {
        return [
            'display_name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:32'],
            'national_id' => ['nullable', 'string', 'max:32'],
            'birth_date' => ['nullable', 'date', 'before:today'],
            'specialization' => ['nullable', 'string', 'max:255'],
            'qualification' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'hired_on' => ['nullable', 'date'],
            'status' => ['required', Rule::enum(TeacherStatus::class)],
            'notes' => ['nullable', 'string'],
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function handle(Institute $institute, array $attributes, ?Teacher $existing = null): Teacher
    {
        // الفراغُ من الاستمارة يُخزَّن null لا نصّاً فارغاً.
        $attributes = collect($attributes)->map(fn ($value) => $value === '' ? null : $value)->all();

        if ($existing !== null) {
            $existing->update($attributes);

            return $existing->refresh();
        }

        return Teacher::create([...$attributes, 'institute_id' => $institute->id]);
    }
}
