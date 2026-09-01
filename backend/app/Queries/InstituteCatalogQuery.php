<?php

namespace App\Queries;

use App\Models\Course;
use App\Models\Curriculum;
use App\Models\CustomField;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Shift;
use App\Models\Teacher;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;

/**
 * قوائم المعهد المرجعية: الدورات، والدوامات، والأساتذة، والمناهج، والصفات، والواصفات.
 *
 * جُمعت في صنف واحد لا ستّة أصناف بسطرٍ واحد لكلٍّ: كلها قراءةُ كتالوجٍ لمعهدٍ واحد،
 * وتفريقها كان سيُنتج طبقةً من الملفات الفارغة بلا مقابل.
 */
class InstituteCatalogQuery
{
    /**
     * @return Collection<int, Course>
     */
    public function courses(?Institute $institute): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return $institute->courses()
            ->withCount('courseCircles')
            ->orderByDesc('is_current')
            ->orderByDesc('starts_on')
            ->get();
    }

    /**
     * @return Collection<int, Shift>
     */
    public function shifts(?Course $course): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        return $course->shifts()
            ->with('days')
            ->withCount('courseCircles')
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * الأساتذة مع عدد حلقاتهم القائمة في الدورة الجارية.
     *
     * @return LengthAwarePaginator<int, Teacher>
     */
    public function teachers(?Institute $institute, ?Course $course, string $search = '', int $perPage = 20): LengthAwarePaginator
    {
        $courseId = $course?->id;

        return Teacher::query()
            ->where('institute_id', $institute?->id)
            ->when($search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('display_name', 'like', "%{$search}%")
                ->orWhere('phone', 'like', "%{$search}%")
                ->orWhere('specialization', 'like', "%{$search}%")))
            ->withCount(['courseCircles as current_circles_count' => fn ($query) => $query
                ->where('course_id', $courseId)
                ->whereNull('course_circle_teachers.left_on')])
            ->orderBy('display_name')
            ->paginate($perPage);
    }

    /**
     * المناهج العامة (institute_id = null) إلى جانب مناهج المعهد.
     *
     * @return Collection<int, Curriculum>
     */
    public function curricula(?Institute $institute): Collection
    {
        return Curriculum::query()
            ->where(fn ($query) => $query->whereNull('institute_id')->orWhere('institute_id', $institute?->id))
            ->with('items')
            ->withCount('items')
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * الصفات المزروعة عامةً إلى جانب صفات المعهد.
     *
     * @return Collection<int, PersonalTrait>
     */
    public function personalTraits(?Institute $institute): Collection
    {
        return PersonalTrait::query()
            ->where(fn ($query) => $query->whereNull('institute_id')->orWhere('institute_id', $institute?->id))
            ->withCount('students')
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * @return Collection<int, CustomField>
     */
    public function customFields(?Institute $institute): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return CustomField::query()
            ->where('institute_id', $institute->id)
            ->orderBy('entity')
            ->orderBy('sort_order')
            ->get();
    }
}
