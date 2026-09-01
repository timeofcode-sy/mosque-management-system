<?php

namespace Database\Factories;

use App\Enums\AttendanceStatus;
use App\Models\AttendanceSession;
use App\Models\Teacher;
use App\Models\TeacherAttendance;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<TeacherAttendance>
 */
class TeacherAttendanceFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'attendance_session_id' => AttendanceSession::factory(),
            'teacher_id' => Teacher::factory(),
            'status' => AttendanceStatus::Present,
            'recorded_at' => Carbon::now(),
        ];
    }
}
