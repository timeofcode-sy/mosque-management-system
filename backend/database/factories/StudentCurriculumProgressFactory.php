<?php

namespace Database\Factories;

use App\Enums\ProgressStatus;
use App\Models\CurriculumItem;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<StudentCurriculumProgress>
 */
class StudentCurriculumProgressFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'student_id' => Student::factory(),
            'curriculum_item_id' => CurriculumItem::factory(),
            'status' => ProgressStatus::NotStarted,
            'percent' => 0,
        ];
    }

    public function memorized(): static
    {
        return $this->state(fn (): array => [
            'status' => ProgressStatus::Memorized,
            'percent' => 100,
            'score' => fake()->numberBetween(70, 100),
        ]);
    }
}
