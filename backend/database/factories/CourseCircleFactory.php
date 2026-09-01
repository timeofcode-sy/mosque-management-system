<?php

namespace Database\Factories;

use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Shift;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<CourseCircle>
 */
class CourseCircleFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'course_id' => Course::factory(),
            'circle_id' => fn (array $attributes): int => Circle::factory()->create([
                'institute_id' => Course::findOrFail($attributes['course_id'])->institute_id,
            ])->id,
            'shift_id' => fn (array $attributes): int => Shift::factory()->create([
                'course_id' => $attributes['course_id'],
            ])->id,
            'room' => 'القاعة '.fake()->numberBetween(1, 8),
            'capacity' => 20,
            'status' => 'active',
        ];
    }
}
