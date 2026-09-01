<?php

namespace Database\Factories;

use App\Enums\MemorizationType;
use App\Models\MemorizationLog;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<MemorizationLog>
 */
class MemorizationLogFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'student_id' => Student::factory(),
            'date' => Carbon::today(),
            'type' => MemorizationType::Hifz,
            'pages' => fake()->randomFloat(2, 0.5, 3),
            'memorization_score' => fake()->numberBetween(60, 100),
            'tajweed_score' => fake()->numberBetween(60, 100),
            'mistakes_count' => fake()->numberBetween(0, 6),
        ];
    }
}
