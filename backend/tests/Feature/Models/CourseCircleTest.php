<?php

namespace Tests\Feature\Models;

use App\Enums\TeacherRole;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\Teacher;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CourseCircleTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_circle_runs_in_a_single_shift_within_one_course(): void
    {
        $institute = Institute::factory()->create();
        $course = Course::factory()->create(['institute_id' => $institute->id]);
        $circle = Circle::factory()->create(['institute_id' => $institute->id]);
        $morning = Shift::factory()->create(['course_id' => $course->id]);
        $evening = Shift::factory()->evening()->create(['course_id' => $course->id]);

        CourseCircle::factory()->create([
            'course_id' => $course->id,
            'circle_id' => $circle->id,
            'shift_id' => $morning->id,
        ]);

        $this->expectException(UniqueConstraintViolationException::class);

        CourseCircle::factory()->create([
            'course_id' => $course->id,
            'circle_id' => $circle->id,
            'shift_id' => $evening->id,
        ]);
    }

    public function test_the_same_circle_can_run_again_in_another_course(): void
    {
        $institute = Institute::factory()->create();
        $circle = Circle::factory()->create(['institute_id' => $institute->id]);

        $previousCourse = Course::factory()->archived()->create(['institute_id' => $institute->id]);
        $currentCourse = Course::factory()->current()->create(['institute_id' => $institute->id]);

        CourseCircle::factory()->create([
            'course_id' => $previousCourse->id,
            'circle_id' => $circle->id,
            'shift_id' => Shift::factory()->create(['course_id' => $previousCourse->id])->id,
        ]);

        CourseCircle::factory()->create([
            'course_id' => $currentCourse->id,
            'circle_id' => $circle->id,
            'shift_id' => Shift::factory()->create(['course_id' => $currentCourse->id])->id,
        ]);

        $this->assertCount(2, $circle->courseCircles()->get());
    }

    public function test_it_exposes_its_assigned_teachers(): void
    {
        $courseCircle = CourseCircle::factory()->create();
        $teacher = Teacher::factory()->create([
            'institute_id' => $courseCircle->course->institute_id,
        ]);

        CourseCircleTeacher::create([
            'course_circle_id' => $courseCircle->id,
            'teacher_id' => $teacher->id,
            'role' => TeacherRole::Main,
        ]);

        $this->assertTrue($courseCircle->teachers()->get()->contains($teacher));
    }
}
