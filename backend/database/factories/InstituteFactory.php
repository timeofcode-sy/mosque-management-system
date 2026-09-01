<?php

namespace Database\Factories;

use App\Models\Institute;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Institute>
 */
class InstituteFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $name = fake()->randomElement(['النور', 'الهدى', 'الفرقان', 'البيان', 'الإحسان', 'السكينة']);

        return [
            'name' => "معهد {$name} لتحفيظ القرآن الكريم",
            'short_name' => "معهد {$name}",
            'phone' => '09'.fake()->numerify('########'),
            'email' => fake()->safeEmail(),
            'address' => fake()->randomElement(['دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية']).' - '.fake()->streetName(),
            'timezone' => 'Asia/Damascus',
            'is_active' => true,
        ];
    }
}
