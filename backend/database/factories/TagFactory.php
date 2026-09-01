<?php

namespace Database\Factories;

use App\Models\Institute;
use App\Models\Tag;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Tag>
 */
class TagFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'institute_id' => Institute::factory(),
            'name' => fake()->randomElement(['متفوّق', 'يحتاج متابعة', 'حالة اجتماعية', 'حافظ']),
            'slug' => fake()->unique()->slug(2),
            'color' => fake()->hexColor(),
        ];
    }
}
