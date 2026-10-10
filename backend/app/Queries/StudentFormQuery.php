<?php

namespace App\Queries;

use App\Enums\GuardianRelation;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Curriculum;
use App\Models\CustomField;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Student;
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

    /**
     * الإخوة المسجَّلون: طلاب المعهد الذين يطابق اسمُ أبيهم الكامل واسمُ أمّهم الكامل ما في
     * الاستمارة، مجموعين بزوج وليّي أمرهم — فالإخوة المربوطون سلفاً عائلةٌ واحدة، والسجلّات
     * المكرّرة القديمة عائلاتٌ منفصلة يُسأل عن كلٍّ منها. العائلة التي يتبعها الطالب أصلاً لا تُعاد.
     *
     * @return Collection<int, array{key: string, father_id: int, mother_id: int, students: Collection<int, Student>}>
     */
    public function siblingFamilies(Institute $institute, string $fatherFullName, string $motherFullName, ?Student $except = null): Collection
    {
        $fatherFullName = trim($fatherFullName);
        $motherFullName = trim($motherFullName);

        if ($fatherFullName === '' || $motherFullName === '') {
            return new Collection;
        }

        $current = $except?->exists ? $except->guardians()->pluck('guardians.id')->all() : [];

        return Student::query()
            ->where('institute_id', $institute->id)
            ->when($except?->exists, fn ($query) => $query->whereKeyNot($except->id))
            ->whereHas('guardians', fn ($query) => $query
                ->where('full_name', $fatherFullName)
                ->where('guardian_student.relation', GuardianRelation::Father->value))
            ->whereHas('guardians', fn ($query) => $query
                ->where('full_name', $motherFullName)
                ->where('guardian_student.relation', GuardianRelation::Mother->value))
            ->with('guardians')
            ->orderBy('first_name')
            ->get()
            ->groupBy(fn (Student $student) => $student->father()->id.'-'.$student->mother()->id)
            ->map(fn (Collection $students, string $key) => [
                'key' => $key,
                'father_id' => $students->first()->father()->id,
                'mother_id' => $students->first()->mother()->id,
                'students' => $students->values(),
            ])
            ->reject(fn (array $family) => in_array($family['father_id'], $current, true) && in_array($family['mother_id'], $current, true))
            ->values();
    }
}
