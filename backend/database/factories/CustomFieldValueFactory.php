<?php

namespace Database\Factories;

use App\Models\CustomField;
use App\Models\CustomFieldValue;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<CustomFieldValue>
 */
class CustomFieldValueFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'custom_field_id' => CustomField::factory(),
            'entity_type' => Student::class,
            'entity_id' => Student::factory(),
            'value' => fake()->word(),
        ];
    }
}
