<?php

namespace Database\Factories;

use App\Enums\EnrollmentStatus;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Enrollment>
 */
class EnrollmentFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'course_circle_id' => CourseCircle::factory(),
            'student_id' => fn (array $attributes): int => Student::factory()->create([
                'institute_id' => Course::findOrFail(
                    CourseCircle::findOrFail($attributes['course_circle_id'])->course_id
                )->institute_id,
            ])->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => Carbon::today(),
        ];
    }
}
