<?php

namespace Database\Factories;

use App\Enums\TeacherStatus;
use App\Models\Institute;
use App\Models\Teacher;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Teacher>
 */
class TeacherFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $first = fake()->randomElement(['محمد', 'أحمد', 'عبد الله', 'عمر', 'خالد', 'يوسف', 'إبراهيم', 'مصطفى']);
        $family = fake()->randomElement(['الأحمد', 'الحسن', 'العلي', 'الخطيب', 'الشامي', 'الحلبي', 'النجار', 'القاسم']);

        return [
            'institute_id' => Institute::factory(),
            'display_name' => "الأستاذ {$first} {$family}",
            'phone' => '09'.fake()->numerify('########'),
            'specialization' => fake()->randomElement(['حفظ وتجويد', 'قراءات', 'علوم شرعية']),
            'qualification' => fake()->randomElement(['إجازة برواية حفص', 'إجازة في الشريعة', 'دبلوم تربوي']),
            'hired_on' => Carbon::today()->subYears(fake()->numberBetween(1, 8)),
            'status' => TeacherStatus::Active,
        ];
    }
}
