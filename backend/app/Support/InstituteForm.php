<?php

namespace App\Support;

use App\Models\Institute;
use Illuminate\Http\UploadedFile;
use Livewire\Features\SupportFileUploads\TemporaryUploadedFile;

/**
 * قواعد نموذج المعهد وتطبيقه على النموذج — تشترك فيهما شاشتا «بيانات المعهد»
 * و«المعاهد».
 *
 * الحقول موحّدة في x-institute-form-fields، والقواعد والحفظ هنا: لو بقيت مكرّرة في
 * الشاشتين لاختلفت إحداهما عن الأخرى عند أوّل تعديل، وصار للمعهد نموذجان.
 */
class InstituteForm
{
    /**
     * @return array<string, array<int, mixed>>
     */
    public static function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'short_name' => ['nullable', 'string', 'max:100'],
            'phone' => ['nullable', 'string', 'max:32'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'is_active' => ['boolean'],
            'logo' => ['nullable', 'image', 'max:2048'],
            'theme.primary' => ['required', 'string', 'regex:/^#[0-9a-fA-F]{6}$/'],
            'theme.secondary' => ['required', 'string', 'regex:/^#[0-9a-fA-F]{6}$/'],
            'theme.surface' => ['required', 'string', 'regex:/^#[0-9a-fA-F]{6}$/'],
            'attendance.late_grace_minutes' => ['required', 'integer', 'min:0', 'max:240'],
            'points.quran_per_15_lines' => ['required', 'numeric', 'min:0', 'max:1000'],
            'points.hadith_per_item' => ['required', 'numeric', 'min:0', 'max:1000'],
            'points.mutun_per_bayt' => ['required', 'numeric', 'min:0', 'max:1000'],
            'points.attendance.*' => ['required', 'numeric', 'min:-100', 'max:100'],
            'points.grade_multiplier.*' => ['required', 'numeric', 'min:0', 'max:200'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public static function attributes(): array
    {
        return [
            'points.quran_per_15_lines' => 'نقاط كل خمسة عشر سطراً',
            'points.hadith_per_item' => 'نقاط الحديث الواحد',
            'points.mutun_per_bayt' => 'نقاط البيت الواحد',
            'theme.primary' => 'اللون الأساسي',
            'theme.secondary' => 'اللون الثانوي',
            'theme.surface' => 'لون الأرضية',
            'attendance.late_grace_minutes' => 'فترة السماح',
        ];
    }

    /**
     * الحقول جاهزةً للإسناد على النموذج، والشعارُ مخزَّناً إن رُفع.
     *
     * الإعدادات الأخرى في العمود تبقى كما هي — تُستبدل المفاتيح المعروضة في النموذج
     * وحدها (points · theme · attendance)، فإضافةُ مفتاحٍ لاحقاً لا تمسح ما قبله.
     *
     * @param  array<string, mixed>  $validated
     * @param  array<string, mixed>  $points
     * @return array<string, mixed>
     */
    public static function attributesFor(?Institute $institute, array $validated, array $points, UploadedFile|TemporaryUploadedFile|null $logo = null): array
    {
        $theme = InstituteTheme::fromArray((array) ($validated['theme'] ?? []))->toArray();
        $attendance = AttendanceSettings::for(null)->toArray();
        $attendance['late_grace_minutes'] = (int) data_get($validated, 'attendance.late_grace_minutes', 0);

        unset($validated['logo'], $validated['points'], $validated['theme'], $validated['attendance']);

        $attributes = [
            ...$validated,
            'settings' => [
                ...(array) $institute?->settings,
                'points' => $points,
                'theme' => $theme,
                'attendance' => $attendance,
            ],
        ];

        if ($logo !== null) {
            $attributes['logo_path'] = $logo->store('institutes', 'public');
        }

        return $attributes;
    }
}
