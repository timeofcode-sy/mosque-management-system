<?php

namespace App\Actions;

use App\Enums\EnrollmentStatus;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use Illuminate\Support\Carbon;
use RuntimeException;

/**
 * تسجيل طالب في حلقة ضمن دورة. التسجيل الواحد لكل دورة — الحلقة الثانية تمرّ عبر TransferStudent.
 */
class EnrollStudent
{
    public function handle(Student $student, CourseCircle $courseCircle, ?string $enrolledOn = null): Enrollment
    {
        $this->assertNotEnrolledInCourse($student, $courseCircle);
        $this->assertHasRoom($courseCircle);

        return Enrollment::create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => $enrolledOn ?? Carbon::today()->toDateString(),
        ]);
    }

    private function assertNotEnrolledInCourse(Student $student, CourseCircle $courseCircle): void
    {
        $exists = Enrollment::query()
            ->where('student_id', $student->id)
            ->where('status', EnrollmentStatus::Active)
            ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $courseCircle->course_id))
            ->exists();

        if ($exists) {
            throw new RuntimeException('الطالب مسجَّل مسبقاً في حلقة ضمن هذه الدورة.');
        }
    }

    private function assertHasRoom(CourseCircle $courseCircle): void
    {
        if ($courseCircle->capacity === null) {
            return;
        }

        if ($courseCircle->activeEnrollments()->count() >= $courseCircle->capacity) {
            throw new RuntimeException('الحلقة بلغت طاقتها الاستيعابية.');
        }
    }
}
