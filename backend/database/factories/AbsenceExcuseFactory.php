<?php

namespace Database\Factories;

use App\Enums\ExcuseStatus;
use App\Models\AbsenceExcuse;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<AbsenceExcuse>
 */
class AbsenceExcuseFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $from = Carbon::today();

        return [
            'student_id' => Student::factory(),
            'from_date' => $from,
            'to_date' => $from->copy()->addDays(fake()->numberBetween(0, 3)),
            'reason' => fake()->randomElement(['مرض', 'سفر مع العائلة', 'ظرف عائلي', 'موعد طبي']),
            'status' => ExcuseStatus::Pending,
        ];
    }

    public function approved(): static
    {
        return $this->state(fn (): array => [
            'status' => ExcuseStatus::Approved,
            'reviewed_at' => Carbon::now(),
        ]);
    }
}
