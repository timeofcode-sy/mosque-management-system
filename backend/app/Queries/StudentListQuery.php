<?php

namespace App\Queries;

use App\Enums\CustomFieldType;
use App\Enums\EnrollmentStatus;
use App\Enums\ProgressStatus;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CustomField;
use App\Models\Institute;
use App\Models\Student;
use App\Support\ArabicSearch;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\Collection;

/**
 * قائمة الطلاب: بحثٌ عربيٌّ متسامح (App\Support\ArabicSearch) مرتَّبٌ بالأقرب، وتصفيةٌ بمعلومات الطالب
 * نفسه: الحالة والحلقة (أو بلا حلقة)، والجنس والصف وسنة الولادة، والأب المتوفى، والعنوان، والواصفات
 * (كالسكن)، وعدد الأجزاء المحفوظة.
 *
 * ما تحسمه القاعدة يُحسم فيها؛ والبحثُ والعنوانُ والواصفاتُ تُحسم بعد التحميل لأن مطابقتها عربيةٌ
 * متسامحة لا LIKE — وطلابُ معهدٍ واحد مئاتٌ لا ملايين.
 */
class StudentListQuery
{
    public const NO_CIRCLE = 'none';

    /**
     * @param  array<string, mixed>  $filters  status · circle · gender · grade · born_from · born_to · father · address · juz_min · fields[معرّف الواصفة]
     * @return array{page: LengthAwarePaginator<int, Student>, approximate: bool, total: int}
     */
    public function search(?Institute $institute, string $search = '', array $filters = [], int $perPage = 20, ?int $page = null): array
    {
        $students = $this->filtered($institute, $filters);
        $approximate = false;

        if (ArabicSearch::words($search) !== []) {
            $scored = $students->map(fn (Student $student) => [
                'student' => $student,
                ...ArabicSearch::match($search, $this->searchable($student)),
            ]);

            $exact = $scored->where('complete', true);

            // لا تطابقَ تامّاً: أقربُ النتائج، ويُقال ذلك في الصفحة.
            if ($exact->isEmpty()) {
                $exact = $scored->where('score', '>', 0.3);
                $approximate = $exact->isNotEmpty();
            }

            $students = $exact
                ->sortBy([['score', 'desc'], [fn (array $a, array $b) => $this->name($a['student']) <=> $this->name($b['student'])]])
                ->pluck('student')
                ->values();
        }

        $page ??= Paginator::resolveCurrentPage();

        return [
            'page' => new LengthAwarePaginator(
                $students->forPage($page, $perPage)->values(),
                $students->count(),
                $perPage,
                $page,
                ['path' => Paginator::resolveCurrentPath()],
            ),
            'approximate' => $approximate,
            'total' => $students->count(),
        ];
    }

    /**
     * @param  array<string, mixed>  $filters
     * @return Collection<int, Student>
     */
    private function filtered(?Institute $institute, array $filters): Collection
    {
        $circle = (string) ($filters['circle'] ?? '');

        $students = Student::query()
            ->where('institute_id', $institute?->id)
            ->when(filled($filters['status'] ?? null), fn ($query) => $query->where('status', $filters['status']))
            ->when(filled($filters['gender'] ?? null), fn ($query) => $query->where('gender', $filters['gender']))
            ->when(filled($filters['grade'] ?? null), fn ($query) => $query->where('grade_level', $filters['grade']))
            ->when(filled($filters['born_from'] ?? null), fn ($query) => $query->whereDate('birth_date', '>=', "{$filters['born_from']}-01-01"))
            ->when(filled($filters['born_to'] ?? null), fn ($query) => $query->whereDate('birth_date', '<=', "{$filters['born_to']}-12-31"))
            ->when($circle === self::NO_CIRCLE, fn ($query) => $query->whereDoesntHave('enrollments', fn ($inner) => $inner
                ->where('status', EnrollmentStatus::Active)))
            ->when($circle !== '' && $circle !== self::NO_CIRCLE, fn ($query) => $query->whereHas('enrollments', fn ($inner) => $inner
                ->where('status', EnrollmentStatus::Active)
                ->where('course_circle_id', $circle)))
            ->with([
                'guardians',
                'customFieldValues',
                'enrollments' => fn ($query) => $query->where('status', EnrollmentStatus::Active)->with('courseCircle.circle'),
            ])
            ->withCount(['curriculumProgress as memorized_juz' => fn ($query) => $query
                ->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered])
                ->whereHas('curriculumItem', fn ($item) => $item->where('code', 'like', 'juz-%'))])
            ->orderBy('family_name')
            ->orderBy('first_name')
            ->get();

        $father = (string) ($filters['father'] ?? '');
        $address = ArabicSearch::normalize($filters['address'] ?? '');
        $juzMin = (int) ($filters['juz_min'] ?? 0);
        $fields = array_filter((array) ($filters['fields'] ?? []), fn ($value) => filled($value));

        return $students->filter(function (Student $student) use ($father, $address, $juzMin, $fields): bool {
            $dad = $student->father();

            if ($father === 'deceased' && ($dad === null || $dad->is_alive)) {
                return false;
            }

            if ($father === 'alive' && $dad !== null && ! $dad->is_alive) {
                return false;
            }

            if ($address !== '' && ! str_contains(ArabicSearch::normalize("{$student->current_address} {$student->permanent_address}"), $address)) {
                return false;
            }

            if ($juzMin > 0 && $student->memorized_juz < $juzMin) {
                return false;
            }

            foreach ($fields as $fieldId => $wanted) {
                $value = $student->customFieldValues->firstWhere('custom_field_id', (int) $fieldId)?->value;
                $values = array_map(fn ($item) => ArabicSearch::normalize((string) $item), (array) $value);

                if (! in_array(ArabicSearch::normalize((string) $wanted), $values, true)) {
                    return false;
                }
            }

            return true;
        })->values();
    }

    /**
     * ما يُبحث فيه: الاسم الثلاثي، ورقم المعرف، وجوال الطالب، واسما الوالدين وجوالاهما.
     *
     * @return list<string>
     */
    private function searchable(Student $student): array
    {
        return [
            $student->first_name, $student->father_name, $student->family_name,
            (string) $student->registration_no, (string) $student->phone,
            ...$student->guardians->flatMap(fn ($guardian) => [$guardian->full_name, (string) $guardian->phone])->all(),
        ];
    }

    private function name(Student $student): string
    {
        return ArabicSearch::normalize($student->full_name);
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

    /**
     * خيارات التصفية المتقدّمة من بيانات المعهد نفسه: الصفوف وسنوات الولادة الموجودة، والواصفات
     * ذات الخيارات (السكن…) بخياراتها.
     *
     * @return array{grades: list<string>, years: list<int>, fields: Collection<int, CustomField>}
     */
    public function filterOptions(?Institute $institute): array
    {
        $students = Student::query()->where('institute_id', $institute?->id);

        return [
            'grades' => (clone $students)->whereNotNull('grade_level')->where('grade_level', '!=', '')
                ->distinct()->orderBy('grade_level')->pluck('grade_level')->all(),
            'years' => (clone $students)->whereNotNull('birth_date')->pluck('birth_date')
                ->map(fn ($date) => (int) $date->format('Y'))->unique()->sortDesc()->values()->all(),
            'fields' => CustomField::query()
                ->where('institute_id', $institute?->id)
                ->where('entity', 'student')
                ->where('is_active', true)
                ->whereIn('type', [CustomFieldType::Select, CustomFieldType::MultiSelect])
                ->orderBy('sort_order')
                ->get(),
        ];
    }
}
