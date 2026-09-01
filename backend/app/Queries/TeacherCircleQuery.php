<?php

namespace App\Queries;

use App\Models\AttendanceSession;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Teacher;
use Illuminate\Support\Collection;

/**
 * حلقات الأستاذ المسنَدة في الدورة الجارية، وجلسات كل حلقة في تاريخ محدَّد — أساس تطبيق الأستاذ.
 */
class TeacherCircleQuery
{
    /**
     * @return Collection<int, CourseCircle>
     */
    public function circles(Teacher $teacher, ?Course $course): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        return CourseCircle::query()
            ->where('course_id', $course->id)
            ->whereHas('teachers', fn ($query) => $query->where('teachers.id', $teacher->id))
            ->with(['circle', 'shift.days'])
            ->withCount('activeEnrollments')
            ->get();
    }

    public function sessionOn(CourseCircle $courseCircle, string $date): ?AttendanceSession
    {
        return $courseCircle->attendanceSessions()
            ->with('attendances.student')
            ->whereDate('session_date', $date)
            ->first();
    }
}
