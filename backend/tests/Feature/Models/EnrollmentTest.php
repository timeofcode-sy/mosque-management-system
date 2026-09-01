<?php

namespace Tests\Feature\Models;

use App\Enums\EnrollmentStatus;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EnrollmentTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_student_is_enrolled_once_per_course_circle(): void
    {
        $enrollment = Enrollment::factory()->create();

        $this->expectException(UniqueConstraintViolationException::class);

        Enrollment::factory()->create([
            'course_circle_id' => $enrollment->course_circle_id,
            'student_id' => $enrollment->student_id,
        ]);
    }

    public function test_the_active_scope_hides_students_who_left_or_moved(): void
    {
        $courseCircle = CourseCircle::factory()->create();
        $instituteId = $courseCircle->course->institute_id;

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => Student::factory()->create(['institute_id' => $instituteId])->id,
        ]);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => Student::factory()->create(['institute_id' => $instituteId])->id,
            'status' => EnrollmentStatus::Transferred,
        ]);

        $this->assertCount(2, $courseCircle->enrollments()->get());
        $this->assertCount(1, $courseCircle->enrollments()->active()->get());
    }

    public function test_a_student_keeps_the_history_of_every_circle_joined(): void
    {
        $student = Student::factory()->create();
        $first = CourseCircle::factory()->create();
        $second = CourseCircle::factory()->create();

        Enrollment::factory()->create([
            'course_circle_id' => $first->id,
            'student_id' => $student->id,
            'status' => EnrollmentStatus::Transferred,
        ]);

        Enrollment::factory()->create([
            'course_circle_id' => $second->id,
            'student_id' => $student->id,
        ]);

        $this->assertCount(2, $student->enrollments()->get());
        $this->assertSame($second->id, $student->activeEnrollment()?->course_circle_id);
    }
}
