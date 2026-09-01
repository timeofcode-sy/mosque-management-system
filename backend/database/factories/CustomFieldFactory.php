<?php

namespace Database\Factories;

use App\Enums\CustomFieldType;
use App\Models\CustomField;
use App\Models\Institute;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<CustomField>
 */
class CustomFieldFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'institute_id' => Institute::factory(),
            'entity' => 'student',
            'key' => fake()->unique()->slug(2),
            'label' => 'واصفة '.fake()->word(),
            'type' => CustomFieldType::Text,
            'is_required' => false,
            'is_active' => true,
            'sort_order' => 0,
        ];
    }
}
