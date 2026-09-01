<?php

namespace App\Queries;

use App\Enums\EnrollmentStatus;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Support\Collection;

/**
 * قراءات شاشتَي الحلقات: هوية الحلقات، وتشغيلها في الدورة، وطلابها وأساتذتها.
 */
class CircleQuery
{
    /**
     * هوية الحلقات في المعهد، محمَّلةً بتشغيلها في الدورة الجارية (courseCircles)
     * حتى تعرض الشاشة الدوام والأستاذ دون استعلام لكل صف.
     *
     * @return Collection<int, Circle>
     */
    public function circles(?Institute $institute, ?Course $course): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        $courseId = $course?->id;

        return $institute->circles()
            ->with(['courseCircles' => fn ($query) => $query->where('course_id', $courseId)->with('shift', 'teachers')])
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();
    }

    /**
     * @return Collection<int, Shift>
     */
    public function shifts(?Course $course): Collection
    {
        return $course?->shifts()->orderBy('sort_order')->get() ?? new Collection;
    }

    /**
     * التسجيلات الجارية في الحلقة، مرتّبة باسم الطالب.
     *
     * @return Collection<int, Enrollment>
     */
    public function activeEnrollments(CourseCircle $courseCircle): Collection
    {
        return $courseCircle->enrollments()
            ->with('student')
            ->where('status', EnrollmentStatus::Active)
            ->get()
            ->sortBy(fn (Enrollment $enrollment) => $enrollment->student->full_name)
            ->values();
    }

    /**
     * إسنادات الأساتذة القائمة على الحلقة.
     *
     * @return Collection<int, CourseCircleTeacher>
     */
    public function assignments(CourseCircle $courseCircle): Collection
    {
        return $courseCircle->courseCircleTeachers()
            ->with('teacher')
            ->whereNull('left_on')
            ->get();
    }

    /**
     * طلاب المعهد غير المسجَّلين في أي حلقة ضمن هذه الدورة.
     *
     * @return Collection<int, Student>
     */
    public function enrollableStudents(CourseCircle $courseCircle): Collection
    {
        return Student::query()
            ->where('institute_id', $courseCircle->course->institute_id)
            ->whereDoesntHave('enrollments', fn ($query) => $query
                ->where('status', EnrollmentStatus::Active)
                ->whereHas('courseCircle', fn ($inner) => $inner->where('course_id', $courseCircle->course_id)))
            ->orderBy('first_name')
            ->get();
    }

    /**
     * الحلقات الأخرى في الدورة نفسها — وجهات النقل الممكنة.
     *
     * @return Collection<int, CourseCircle>
     */
    public function transferTargets(CourseCircle $courseCircle): Collection
    {
        return CourseCircle::query()
            ->where('course_id', $courseCircle->course_id)
            ->whereKeyNot($courseCircle->id)
            ->with('circle')
            ->get();
    }

    /**
     * @return Collection<int, Teacher>
     */
    public function assignableTeachers(?Institute $institute): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return Teacher::query()
            ->where('institute_id', $institute->id)
            ->orderBy('display_name')
            ->get();
    }
}
