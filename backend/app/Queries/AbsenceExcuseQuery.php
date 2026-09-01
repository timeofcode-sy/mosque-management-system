<?php

namespace App\Queries;

use App\Enums\ExcuseStatus;
use App\Models\AbsenceExcuse;
use App\Models\Institute;
use App\Models\Student;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;

/**
 * قراءات شاشة أذونات الغياب المسبقة.
 */
class AbsenceExcuseQuery
{
    /**
     * @return LengthAwarePaginator<int, AbsenceExcuse>
     */
    public function paginate(?Institute $institute, string $status = '', string $search = '', int $perPage = 15): LengthAwarePaginator
    {
        $query = AbsenceExcuse::query()
            ->with('student', 'submittedBy', 'reviewedBy')
            ->whereHas('student', fn ($builder) => $builder->where('institute_id', $institute?->id));

        if ($status !== '') {
            $query->where('status', $status);
        }

        if ($search !== '') {
            $query->whereHas('student', fn ($builder) => $builder
                ->where('first_name', 'like', "%{$search}%")
                ->orWhere('family_name', 'like', "%{$search}%")
                ->orWhere('registration_no', 'like', "%{$search}%"));
        }

        return $query
            ->orderByRaw('case when status = ? then 0 else 1 end', [ExcuseStatus::Pending->value])
            ->orderByDesc('from_date')
            ->paginate($perPage);
    }

    public function pendingCount(?Institute $institute): int
    {
        if ($institute === null) {
            return 0;
        }

        return AbsenceExcuse::query()
            ->where('status', ExcuseStatus::Pending)
            ->whereHas('student', fn ($builder) => $builder->where('institute_id', $institute->id))
            ->count();
    }

    /**
     * طلاب المعهد لقائمة اختيار الطالب في نموذج الإذن.
     *
     * @return Collection<int, Student>
     */
    public function selectableStudents(?Institute $institute): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return Student::query()
            ->where('institute_id', $institute->id)
            ->orderBy('first_name')
            ->get(['id', 'first_name', 'father_name', 'family_name', 'registration_no']);
    }
}
