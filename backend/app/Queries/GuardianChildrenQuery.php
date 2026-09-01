<?php

namespace App\Queries;

use App\Models\Attendance;
use App\Models\Guardian;
use App\Models\Student;
use Illuminate\Support\Collection;

/**
 * أبناء ولي الأمر وسجل حضورهم — أساس تطبيق الأهل.
 */
class GuardianChildrenQuery
{
    /**
     * @return Collection<int, Student>
     */
    public function children(Guardian $guardian): Collection
    {
        return $guardian->students()->get();
    }

    /**
     * @return Collection<int, Attendance>
     */
    public function attendanceOf(Student $student, int $limit = 30): Collection
    {
        return $student->attendances()
            ->with('attendanceSession')
            ->latest('recorded_at')
            ->limit($limit)
            ->get();
    }
}
