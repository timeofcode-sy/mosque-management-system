<?php

namespace Database\Factories;

use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<AttendanceSession>
 */
class AttendanceSessionFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'course_circle_id' => CourseCircle::factory(),
            'session_date' => Carbon::today(),
            'status' => SessionStatus::Draft,
        ];
    }

    public function completed(): static
    {
        return $this->state(fn (): array => [
            'status' => SessionStatus::Completed,
            'completed_at' => Carbon::now(),
        ]);
    }

    public function locked(): static
    {
        return $this->state(fn (): array => [
            'status' => SessionStatus::Locked,
            'completed_at' => Carbon::now(),
        ]);
    }
}
