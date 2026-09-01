<?php

namespace Database\Factories;

use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Student;
use App\Models\StudentTransfer;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<StudentTransfer>
 */
class StudentTransferFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'student_id' => Student::factory(),
            'course_id' => Course::factory(),
            'from_course_circle_id' => CourseCircle::factory(),
            'to_course_circle_id' => CourseCircle::factory(),
            'transferred_on' => Carbon::today(),
            'reason' => fake()->randomElement(['تغيير الدوام', 'مستوى الحفظ', 'طلب ولي الأمر']),
        ];
    }
}
