<?php

namespace Database\Factories;

use App\Enums\CurriculumType;
use App\Models\Curriculum;
use App\Models\Institute;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Curriculum>
 */
class CurriculumFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'institute_id' => Institute::factory(),
            'name' => 'منهج '.fake()->unique()->word(),
            'slug' => fake()->unique()->slug(2),
            'type' => CurriculumType::Custom,
            'sort_order' => 0,
            'is_active' => true,
        ];
    }
}
