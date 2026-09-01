<?php

namespace Database\Factories;

use App\Models\Shift;
use App\Models\ShiftDay;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ShiftDay>
 */
class ShiftDayFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'shift_id' => Shift::factory(),
            'weekday' => fake()->numberBetween(0, 6),
        ];
    }
}
