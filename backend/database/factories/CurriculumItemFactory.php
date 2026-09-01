<?php

namespace Database\Factories;

use App\Models\Curriculum;
use App\Models\CurriculumItem;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<CurriculumItem>
 */
class CurriculumItemFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'curriculum_id' => Curriculum::factory(),
            'name' => 'بند '.fake()->unique()->word(),
            'code' => fake()->unique()->slug(2),
            'sort_order' => 0,
            'is_active' => true,
        ];
    }
}
