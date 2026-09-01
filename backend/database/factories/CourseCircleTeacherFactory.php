<?php

namespace Database\Factories;

use App\Enums\TeacherRole;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Teacher;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<CourseCircleTeacher>
 */
class CourseCircleTeacherFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'course_circle_id' => CourseCircle::factory(),
            'teacher_id' => fn (array $attributes): int => Teacher::factory()->create([
                'institute_id' => Course::findOrFail(
                    CourseCircle::findOrFail($attributes['course_circle_id'])->course_id
                )->institute_id,
            ])->id,
            'role' => TeacherRole::Main,
            'joined_on' => Carbon::today(),
        ];
    }
}
