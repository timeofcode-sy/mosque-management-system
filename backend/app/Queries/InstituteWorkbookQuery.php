<?php

namespace App\Queries;

use App\Actions\ImportInstitute;
use App\Enums\CurriculumType;
use App\Enums\GuardianRelation;
use App\Enums\MemorizationType;
use App\Enums\ProgressStatus;
use App\Models\CourseCircle;
use App\Models\Guardian;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\Teacher;
use App\Support\Quran;
use Illuminate\Support\Collection;

/**
 * بيانات معهدٍ كاملةً في مصنّف — بأوراق مصنّف الاستيراد نفسها وأعمدته (docs/IMPORT.md)، فيصلح
 * نسخةً تُقرأ وتُعاد إلى institute:import. وتزيد عليها أعمدةٌ للعرض يتجاهلها الاستيراد (اسم
 * المستخدم، الحالة…) وورقتان: أولياء الأمور والحسابات.
 *
 * كلماتُ المرور لا تخرج هنا: الورقة تقول أصدرت أم لا، والكلماتُ نفسها في «بيانات الدخول»
 * خلف صلاحيتها.
 */
class InstituteWorkbookQuery
{
    private const WEEKDAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    /**
     * @return array<string, list<list<string|int|null>>>
     */
    public function sheets(Institute $institute): array
    {
        $course = $institute->currentCourse();
        $courseCircles = $course?->courseCircles()->with('circle', 'shift', 'teachers')->withCount('activeEnrollments')->get()
            ?? collect();

        return [
            ImportInstitute::SHEET_INSTITUTE => [
                ['البند', 'القيمة'],
                ['الاسم', $institute->name],
                ['الاسم المختصر', $institute->short_name],
                ['الدورة', $course?->name],
                ['بداية الدورة', $course?->starts_on?->toDateString()],
                ['نهاية الدورة', $course?->ends_on?->toDateString()],
                ['الإعدادات', json_encode($institute->settings ?? [], JSON_UNESCAPED_UNICODE)],
            ],
            ImportInstitute::SHEET_SHIFTS => [
                ['الدوام', 'البداية', 'النهاية', 'الترتيب', 'الأيام'],
                ...($course?->shifts()->with('days')->orderBy('sort_order')->get() ?? collect())->map(fn ($shift) => [
                    $shift->name, $shift->starts_at, $shift->ends_at, $shift->sort_order,
                    implode('، ', array_map(fn (int $day) => self::WEEKDAYS[$day], $shift->days->pluck('weekday')->sort()->values()->all())),
                ])->all(),
            ],
            ImportInstitute::SHEET_TEACHERS => [
                ['الاسم', 'الجوال', 'اسم المستخدم', 'الحلقات'],
                ...$institute->teachers()->with('user')->orderBy('display_name')->get()->map(fn (Teacher $teacher) => [
                    $teacher->display_name, $teacher->phone, $teacher->user?->username,
                    $courseCircles->filter(fn (CourseCircle $courseCircle) => $courseCircle->teachers->contains($teacher))
                        ->map(fn (CourseCircle $courseCircle) => $courseCircle->circle->name)->implode('، '),
                ])->all(),
            ],
            ImportInstitute::SHEET_CIRCLES => [
                ['الحلقة', 'الدوام', 'الأستاذ', 'الطاقة', 'مفعّلة', 'الترتيب', 'عدد الطلاب'],
                ...$institute->circles()->orderByDesc('is_active')->orderBy('sort_order')->get()->map(function ($circle) use ($courseCircles) {
                    $courseCircle = $courseCircles->firstWhere('circle_id', $circle->id);

                    return [
                        $circle->name, $courseCircle?->shift?->name, $courseCircle?->teachers->first()?->display_name,
                        $courseCircle?->capacity, $circle->is_active ? 'نعم' : 'لا', $circle->sort_order,
                        $courseCircle?->active_enrollments_count,
                    ];
                })->all(),
            ],
            ImportInstitute::SHEET_CUSTOM_FIELDS => [
                ['العنوان', 'المفتاح', 'النوع', 'الخيارات', 'المجموعة', 'مطلوبة'],
                ...$institute->customFields()->where('entity', 'student')->orderBy('sort_order')->get()->map(fn ($field) => [
                    $field->label, $field->key, $field->type->value, implode('، ', $field->options ?? []), $field->group,
                    $field->is_required ? 'نعم' : 'لا',
                ])->all(),
            ],
            ImportInstitute::SHEET_STUDENTS => $this->students($institute, $courseCircles),
            'أولياء الأمور' => $this->guardians($institute),
            'الحسابات' => $this->accounts($institute),
        ];
    }

    /**
     * @param  Collection<int, CourseCircle>  $courseCircles
     * @return list<list<string|int|null>>
     */
    private function students(Institute $institute, $courseCircles): array
    {
        $fields = $institute->customFields()->where('entity', 'student')->orderBy('sort_order')->get();

        $students = $institute->students()
            ->with([
                'guardians', 'user', 'customFieldValues',
                'enrollments' => fn ($query) => $query->where('status', 'active'),
                'curriculumProgress' => fn ($query) => $query->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered]),
                'curriculumProgress.curriculumItem.curriculum',
            ])
            ->orderBy('family_name')->orderBy('first_name')
            ->get();

        $rows = [[
            'المرجع', 'الاسم', 'اسم الأب', 'الكنية', 'الجنس', 'تاريخ الولادة', 'الصف', 'عمل الطالب', 'جوال الطالب', 'العنوان',
            'رمز الأب', 'عمل الأب', 'جوال الأب', 'الأب متوفى', 'رمز الأم', 'اسم الأم', 'كنية الأم', 'عمل الأم', 'جوال الأم',
            'الحلقة', 'الأجزاء المحفوظة', 'السور المحفوظة', 'محفوظات أخرى', ...$fields->pluck('label')->all(), 'ملاحظات',
            'الحالة', 'اسم المستخدم',
        ]];

        foreach ($students as $student) {
            $father = $student->father();
            $mother = $student->mother();
            $progress = $student->curriculumProgress;
            $juz = $progress->filter(fn (StudentCurriculumProgress $row) => $row->curriculumItem?->juz() !== null)
                ->map(fn (StudentCurriculumProgress $row) => $row->curriculumItem->juz())->sortDesc()->values();
            $others = $progress->filter(fn (StudentCurriculumProgress $row) => $row->curriculumItem?->curriculum?->type !== CurriculumType::Quran)
                ->map(fn (StudentCurriculumProgress $row) => $row->curriculumItem?->name)->filter();
            $circle = $courseCircles->firstWhere('id', $student->enrollments->first()?->course_circle_id)?->circle?->name;
            $values = $student->customFieldValues->keyBy('custom_field_id');

            $rows[] = [
                $student->registration_no ?: 'ط'.$student->id,
                $student->first_name, $student->father_name, $student->family_name,
                $student->gender->label(), $student->birth_date?->toDateString(), $student->grade_level, $student->student_job,
                $student->phone, $student->current_address,
                $father ? 'أ'.$father->id : null, $father?->occupation, $father?->phone, $father && ! $father->is_alive ? 'نعم' : null,
                $mother ? 'م'.$mother->id : null, $mother?->first_name, $mother?->family_name, $mother?->occupation, $mother?->phone,
                $circle, $juz->implode('، '), $this->priorSurahs($student), $others->implode('، '),
                ...$fields->map(fn ($field) => $values->get($field->id)?->value)->all(),
                $student->notes, $student->status->label(), $student->user?->username,
            ];
        }

        return $rows;
    }

    /**
     * سورٌ محفوظةٌ قبل الالتحاق: تسميعُ «حفظ» لسورةٍ كاملة خارج أي جلسة — كما يكتبها الاستيراد.
     */
    private function priorSurahs(Student $student): string
    {
        return MemorizationLog::query()
            ->where('student_id', $student->id)
            ->where('type', MemorizationType::Hifz)
            ->whereNull('attendance_session_id')
            ->whereColumn('from_surah', 'to_surah')
            ->where('from_ayah', 1)
            ->orderBy('from_surah')
            ->get()
            ->filter(fn (MemorizationLog $log) => $log->to_ayah === Quran::ayahs($log->from_surah))
            ->map(fn (MemorizationLog $log) => Quran::name($log->from_surah))
            ->unique()
            ->implode('، ');
    }

    /**
     * @return list<list<string|int|null>>
     */
    private function guardians(Institute $institute): array
    {
        $rows = [['الرمز', 'الاسم الكامل', 'الاسم', 'الكنية', 'الصلة', 'الجوال', 'العمل', 'متوفى', 'الأبناء', 'اسم المستخدم']];

        foreach ($institute->guardians()->with('students', 'user')->orderBy('full_name')->get() as $guardian) {
            /** @var Guardian $guardian */
            $relation = GuardianRelation::tryFrom((string) $guardian->students->first()?->pivot->relation);

            $rows[] = [
                ($relation === GuardianRelation::Mother ? 'م' : 'أ').$guardian->id,
                $guardian->full_name, $guardian->first_name, $guardian->family_name, $relation?->label(),
                $guardian->phone, $guardian->occupation, $guardian->is_alive ? null : 'نعم',
                $guardian->students->map(fn (Student $student) => $student->full_name)->implode('، '),
                $guardian->user?->username,
            ];
        }

        return $rows;
    }

    /**
     * @return list<list<string|int|null>>
     */
    private function accounts(Institute $institute): array
    {
        $rows = [['الاسم', 'الدور', 'اسم المستخدم', 'كلمة المرور', 'مفعّل']];

        $records = [
            'أستاذ' => $institute->teachers()->with('user')->get()->map(fn (Teacher $teacher) => [$teacher->display_name, $teacher->user]),
            'ولي أمر' => $institute->guardians()->with('user')->get()->map(fn (Guardian $guardian) => [$guardian->full_name, $guardian->user]),
            'طالب' => $institute->students()->with('user')->get()->map(fn (Student $student) => [$student->full_name, $student->user]),
        ];

        foreach ($records as $role => $people) {
            foreach ($people->sortBy(0) as [$name, $user]) {
                $rows[] = [
                    $name, $role, $user?->username,
                    $user === null ? null : ($user->generated_password === null ? 'لم تُصدَر بعد' : 'صادرة'),
                    $user === null ? null : ($user->is_active ? 'نعم' : 'لا'),
                ];
            }
        }

        return $rows;
    }
}
