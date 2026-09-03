<?php

namespace Database\Factories;

use App\Enums\PointReason;
use App\Models\Student;
use App\Models\StudentPoint;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<StudentPoint>
 */
class StudentPointFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'student_id' => Student::factory(),
            'points' => fake()->randomFloat(2, 1, 5),
            'reason' => PointReason::Participation,
            'awarded_on' => Carbon::today(),
        ];
    }

    public function penalty(): static
    {
        return $this->state(fn (): array => [
            'points' => -fake()->randomFloat(2, 1, 3),
            'reason' => PointReason::Behavior,
        ]);
    }
}
