<?php

namespace Database\Factories;

use App\Models\Guardian;
use App\Models\Institute;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Guardian>
 */
class GuardianFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'institute_id' => Institute::factory(),
            'full_name' => fake()->randomElement(['محمود', 'سامر', 'ماهر', 'عدنان', 'رضوان']).' '.fake()->randomElement(['الأحمد', 'الحسن', 'العلي', 'الخطيب']),
            'phone' => '09'.fake()->numerify('########'),
            'occupation' => fake()->randomElement(['موظف', 'تاجر', 'مزارع', 'سائق', 'معلم', 'عامل بناء', 'خياط']),
            'address' => fake()->streetName(),
            'is_alive' => true,
        ];
    }

    public function mother(): static
    {
        return $this->state(fn (): array => [
            'full_name' => fake()->randomElement(['فاطمة', 'عائشة', 'مريم', 'خديجة', 'زينب', 'سمية']).' '.fake()->randomElement(['الأحمد', 'العلي', 'الشامي']),
            'occupation' => fake()->randomElement(['ربة منزل', 'ربة منزل', 'معلمة', 'ممرضة', 'خياطة']),
        ]);
    }
}
