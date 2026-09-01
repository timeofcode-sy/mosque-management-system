<?php

namespace Database\Factories;

use App\Enums\CourseStatus;
use App\Models\Course;
use App\Models\Institute;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Course>
 */
class CourseFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $startsOn = Carbon::today()->startOfMonth();

        return [
            'institute_id' => Institute::factory(),
            'name' => 'دورة '.fake()->randomElement(['الصيف', 'الشتاء', 'رمضان', 'الربيع']).' '.$startsOn->year,
            'starts_on' => $startsOn,
            'ends_on' => $startsOn->copy()->addMonths(3),
            'status' => CourseStatus::Active,
            'is_current' => false,
        ];
    }

    public function current(): static
    {
        return $this->state(fn (): array => [
            'status' => CourseStatus::Active,
            'is_current' => true,
        ]);
    }

    public function archived(): static
    {
        return $this->state(fn (): array => [
            'status' => CourseStatus::Archived,
            'is_current' => false,
        ]);
    }
}
