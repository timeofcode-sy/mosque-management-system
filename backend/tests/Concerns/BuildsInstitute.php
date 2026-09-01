<?php

namespace Tests\Concerns;

use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\ShiftDay;
use App\Models\User;

/**
 * معهد صغير جاهز لاختبار شاشات اللوحة: دورة جارية، دوام بيومين، وحلقتان.
 */
trait BuildsInstitute
{
    protected Institute $institute;

    protected Course $course;

    protected Shift $shift;

    protected User $admin;

    protected function buildInstitute(): void
    {
        $this->institute = Institute::factory()->create();
        $this->course = Course::factory()->current()->create(['institute_id' => $this->institute->id]);
        $this->shift = Shift::factory()->create(['course_id' => $this->course->id]);

        ShiftDay::factory()->create(['shift_id' => $this->shift->id, 'weekday' => 0]);
        ShiftDay::factory()->create(['shift_id' => $this->shift->id, 'weekday' => 2]);

        $this->admin = User::factory()->create();

        $this->actingAs($this->admin);
        $this->withSession(['institute_id' => $this->institute->id]);
    }

    protected function makeCourseCircle(?string $name = null): CourseCircle
    {
        $courseCircle = CourseCircle::factory()->create([
            'course_id' => $this->course->id,
            'shift_id' => $this->shift->id,
        ]);

        if ($name !== null) {
            $courseCircle->circle->update(['name' => $name]);
        }

        return $courseCircle;
    }
}
