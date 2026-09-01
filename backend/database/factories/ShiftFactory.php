<?php

namespace Database\Factories;

use App\Models\Course;
use App\Models\Shift;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Shift>
 */
class ShiftFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'course_id' => Course::factory(),
            'name' => 'الدوام الصباحي',
            'starts_at' => '08:00',
            'ends_at' => '11:00',
            'sort_order' => 0,
            'is_active' => true,
        ];
    }

    public function evening(): static
    {
        return $this->state(fn (): array => [
            'name' => 'الدوام المسائي',
            'starts_at' => '16:00',
            'ends_at' => '19:00',
            'sort_order' => 1,
        ]);
    }
}
