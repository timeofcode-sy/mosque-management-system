<?php

namespace Database\Factories;

use App\Enums\AttendanceStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Attendance>
 */
class AttendanceFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'attendance_session_id' => AttendanceSession::factory(),
            'student_id' => Student::factory(),
            'status' => AttendanceStatus::Present,
            'recorded_at' => Carbon::now(),
        ];
    }

    public function absent(): static
    {
        return $this->state(fn (): array => ['status' => AttendanceStatus::Absent]);
    }

    public function late(): static
    {
        return $this->state(fn (): array => [
            'status' => AttendanceStatus::Late,
            'late_minutes' => fake()->numberBetween(5, 30),
        ]);
    }

    public function excused(): static
    {
        return $this->state(fn (): array => ['status' => AttendanceStatus::Excused]);
    }
}
