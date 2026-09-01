<?php

namespace App\Queries;

use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Curriculum;
use App\Models\CustomField;
use App\Models\Institute;
use App\Models\PersonalTrait;
use Illuminate\Support\Collection;

/**
 * قوائم الاختيار في استمارة تسجيل الطالب.
 *
 * كلها مقصورة على المفعَّل (is_active) — الاستمارة تعرض ما يصلح للاختيار اليوم،
 * بخلاف شاشات الإعدادات التي تعرض الموقوف أيضاً ليعاد تفعيله.
 */
class StudentFormQuery
{
    /**
     * @return Collection<int, PersonalTrait>
     */
    public function personalTraits(?Institute $institute): Collection
    {
        return PersonalTrait::query()
            ->where('is_active', true)
            ->where(fn ($query) => $query->whereNull('institute_id')->orWhere('institute_id', $institute?->id))
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * @return Collection<int, Curriculum>
     */
    public function curricula(?Institute $institute): Collection
    {
        return Curriculum::query()
            ->where('is_active', true)
            ->where(fn ($query) => $query->whereNull('institute_id')->orWhere('institute_id', $institute?->id))
            ->with('items')
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * @return Collection<int, CustomField>
     */
    public function customFieldDefinitions(?Institute $institute, string $entity = 'student'): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return CustomField::query()
            ->where('institute_id', $institute->id)
            ->where('entity', $entity)
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->get();
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    public function courseCircles(?Course $course): Collection
    {
        return $course?->courseCircles()->with('circle', 'shift')->get() ?? new Collection;
    }
}
