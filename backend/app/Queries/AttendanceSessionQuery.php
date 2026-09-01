<?php

namespace App\Queries;

use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Teacher;
use App\Models\TeacherAttendance;
use Illuminate\Support\Collection;

/**
 * قراءات شاشة التفقّد الواحدة: الجلسة، وصفوفها، وأساتذتها، وأصحاب الأذونات.
 */
class AttendanceSessionQuery
{
    public function session(CourseCircle $courseCircle, string $date): ?AttendanceSession
    {
        return $courseCircle->attendanceSessions()
            ->whereDate('session_date', $date)
            ->first();
    }

    /**
     * صفوف الجلسة مرتّبة باسم الطالب — الترتيب ثابت حتى لا تقفز الأسماء بين الطلبات.
     *
     * @return Collection<int, Attendance>
     */
    public function attendances(?AttendanceSession $session): Collection
    {
        if ($session === null) {
            return new Collection;
        }

        return $session->attendances()
            ->with('student')
            ->get()
            ->sortBy(fn (Attendance $attendance) => $attendance->student->full_name)
            ->values();
    }

    /**
     * @return Collection<int, TeacherAttendance>
     */
    public function teacherAttendances(?AttendanceSession $session): Collection
    {
        if ($session === null) {
            return new Collection;
        }

        return $session->teacherAttendances()->get()->keyBy('teacher_id');
    }

    /**
     * الأساتذة المسنَدون إلى الحلقة في ذلك التاريخ — من انتهى إسناده قبله لا يُتفقَّد.
     *
     * @return Collection<int, Teacher>
     */
    public function assignedTeachers(CourseCircle $courseCircle, string $date): Collection
    {
        return $courseCircle->teachers()
            ->wherePivot('joined_on', '<=', $date)
            ->where(fn ($query) => $query->whereNull('course_circle_teachers.left_on')
                ->orWhereDate('course_circle_teachers.left_on', '>=', $date))
            ->get()
            ->unique('id')
            ->values();
    }

    /**
     * طلاب هذه الحلقة الذين يغطّيهم إذن غياب مقبول في ذلك التاريخ.
     *
     * @return array<int, int>
     */
    public function excusedStudentIds(CourseCircle $courseCircle, string $date): array
    {
        return AbsenceExcuse::query()
            ->covering($date)
            ->whereIn('student_id', $courseCircle->enrollments()->select('student_id'))
            ->pluck('student_id')
            ->all();
    }
}
