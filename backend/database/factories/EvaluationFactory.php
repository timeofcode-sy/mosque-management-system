<?php

namespace Database\Factories;

use App\Enums\EvaluationPeriod;
use App\Models\Evaluation;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Evaluation>
 */
class EvaluationFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $start = Carbon::today()->startOfMonth();
        $behavior = fake()->numberBetween(15, 25);
        $commitment = fake()->numberBetween(15, 25);
        $memorization = fake()->numberBetween(15, 25);
        $tajweed = fake()->numberBetween(15, 25);

        return [
            'student_id' => Student::factory(),
            'period' => EvaluationPeriod::Monthly,
            'period_start' => $start,
            'period_end' => $start->copy()->endOfMonth(),
            'behavior' => $behavior,
            'commitment' => $commitment,
            'memorization' => $memorization,
            'tajweed' => $tajweed,
            'total' => $behavior + $commitment + $memorization + $tajweed,
        ];
    }
}
