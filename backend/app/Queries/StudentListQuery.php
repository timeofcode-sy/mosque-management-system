<?php

namespace App\Queries;

use App\Enums\EnrollmentStatus;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Institute;
use App\Models\Student;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;

/**
 * قائمة الطلاب: البحث بالاسم أو رقم المعرف أو الهاتف، والتصفية بالحالة والحلقة.
 */
class StudentListQuery
{
    /**
     * @return LengthAwarePaginator<int, Student>
     */
    public function paginate(
        ?Institute $institute,
        string $search = '',
        string $status = '',
        string $courseCircleId = '',
        int $perPage = 20,
    ): LengthAwarePaginator {
        return Student::query()
            ->where('institute_id', $institute?->id)
            ->when($search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('first_name', 'like', "%{$search}%")
                ->orWhere('father_name', 'like', "%{$search}%")
                ->orWhere('family_name', 'like', "%{$search}%")
                ->orWhere('registration_no', 'like', "%{$search}%")
                ->orWhere('phone', 'like', "%{$search}%")))
            ->when($status !== '', fn ($query) => $query->where('status', $status))
            ->when($courseCircleId !== '', fn ($query) => $query->whereHas('enrollments', fn ($inner) => $inner
                ->where('status', EnrollmentStatus::Active)
                ->where('course_circle_id', $courseCircleId)))
            ->with(['enrollments' => fn ($query) => $query
                ->where('status', EnrollmentStatus::Active)
                ->with('courseCircle.circle')])
            ->orderBy('family_name')
            ->orderBy('first_name')
            ->paginate($perPage);
    }

    /**
     * حلقات الدورة الجارية — مصدر قائمة التصفية.
     *
     * @return Collection<int, CourseCircle>
     */
    public function filterableCircles(?Course $course): Collection
    {
        return $course?->courseCircles()->with('circle')->get() ?? new Collection;
    }
}
