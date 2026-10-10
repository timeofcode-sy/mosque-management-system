<?php

namespace Database\Seeders;

use App\Actions\PublishAnnouncement;
use App\Enums\AttendanceStatus;
use App\Enums\CourseStatus;
use App\Enums\CustomFieldType;
use App\Enums\EnrollmentStatus;
use App\Enums\EvaluationPeriod;
use App\Enums\ProgressStatus;
use App\Models\Attendance;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\CustomField;
use App\Models\CustomFieldValue;
use App\Models\Enrollment;
use App\Models\Evaluation;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\Tag;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * ما يحيط بالطالب خارج الحضور والحفظ: الإعلانات بفئاتها، وتقييم الشهر الماضي، والوسوم،
 * والواصفات المخصّصة — فتُفتح الشاشات التي تعرضها على بياناتٍ لا على قوائم فارغة.
 *
 * يعمل بعد `DemoMemorizationSeeder` لأن الوسوم تُشتقّ من الحفظ والحضور المبذورَين لا
 * من العشوائية: «حافظ لجزء عمّ» لا يوسَم به إلا من أتمّه فعلاً.
 */
class DemoExtrasSeeder extends Seeder
{
    /**
     * @var array<int, string>
     */
    private const EVALUATION_NOTES = [
        'مواظبٌ ومجتهد، نسأل الله له التوفيق.',
        'يحتاج إلى مزيدٍ من الالتزام بالمراجعة في البيت.',
        'تحسّنٌ ملحوظ في التجويد هذا الشهر.',
        'جيّد السلوك، وينقصه الانتظام في الحضور.',
    ];

    /**
     * @var array<string, string>
     */
    private const SCHOOLS = [
        'ابتدائي' => 'مدرسة عربين الابتدائية',
        'متوسط' => 'مدرسة الأمل الإعدادية',
        'ثانوي' => 'ثانوية عربين',
    ];

    private Course $course;

    /** @var Collection<int, Teacher> أستاذ كل حلقة، بمفتاح course_circle_id */
    private Collection $teachers;

    public function run(Institute $institute, User $admin): void
    {
        $this->course = Course::query()
            ->where('institute_id', $institute->id)
            ->where('status', CourseStatus::Active)
            ->firstOrFail();

        $this->teachers = CourseCircleTeacher::query()
            ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $this->course->id))
            ->with('teacher')
            ->get()
            ->mapWithKeys(fn (CourseCircleTeacher $row) => [$row->course_circle_id => $row->teacher]);

        $this->seedAnnouncements($institute, $admin);
        $this->seedEvaluations();
        $this->seedTags($institute);
        $this->seedCustomFields($institute);
    }

    /**
     * ستة إعلانات تغطّي الفئات الثلاث والنطاقين، وواحدٌ مسوَّدة لم يُنشر — ليرى كل تطبيق
     * ما يخصّه فقط، وليرى المشرف الحالات كلَّها في لوحته.
     */
    private function seedAnnouncements(Institute $institute, User $admin): void
    {
        $firstCircle = CourseCircle::query()->where('course_id', $this->course->id)->orderBy('id')->first();
        $publish = app(PublishAnnouncement::class);

        $announcements = [
            ['انتظام الدوام', 'نذكّر الطلابَ بالحضور قبل بداية الحصّة بعشر دقائق، وجزاكم الله خيراً.', 'all', null, ['students', 'guardians'], now()->subDays(3)],
            ['مسابقة حفظ جزء عمّ', 'تُقام المسابقةُ نهايةَ الشهر، والتسجيلُ عند أستاذ الحلقة.', 'all', null, ['students', 'guardians', 'teachers'], now()->subDay()],
            ['اجتماع الأساتذة الشهري', 'يُعقد الاجتماعُ بعد صلاة العصر يوم الخميس لمناقشة خطة المراجعة والامتحانات.', 'all', null, ['teachers'], now()->subDays(2)],
            ['لقاء أولياء الأمور', 'ندعو أولياءَ الأمور إلى لقاءٍ يوم السبت بعد العصر للاطّلاع على مستوى أبنائهم.', 'all', null, ['guardians'], now()->subDays(5)],
            ['تغيير موعد الحصة', 'تُقدَّم حصّةُ الحلقة يوم الأحد القادم نصفَ ساعة، فنرجو الالتزام بالموعد الجديد.', 'circle', [$firstCircle?->id], ['students', 'guardians'], now()->subHours(12)],
            ['إجازة نهاية الدورة', 'مسوَّدة: موعد الإجازة وبرنامج الحفل الختامي — لم يُعتمد بعد.', 'all', null, ['students', 'guardians', 'teachers'], null],
        ];

        foreach ($announcements as [$title, $body, $scope, $scopeIds, $audience, $publishedAt]) {
            $publish->handle($institute, [
                'title' => $title,
                'body' => $body,
                'scope' => $scope,
                'scope_ids' => array_filter((array) $scopeIds),
                'audience' => $audience,
                'published_at' => $publishedAt?->toDateTimeString(),
            ], $admin);
        }
    }

    /**
     * تقييم الشهر الماضي لكل طالب مسجَّل: أربعة محاور من خمسةٍ وعشرين، لكل طالبٍ «مستوى»
     * عامّ تدور حوله درجاتُه بتفاوتٍ بسيط — الطالب المجتهد مجتهدٌ في المحاور كلها.
     */
    private function seedEvaluations(): void
    {
        $start = Carbon::today()->subMonthNoOverflow()->startOfMonth();

        $enrollments = Enrollment::query()
            ->where('status', EnrollmentStatus::Active)
            ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $this->course->id))
            ->get();

        foreach ($enrollments as $enrollment) {
            $level = fake()->numberBetween(0, 100);
            $score = fn (): int => max(10, min(25, (int) round(15 + $level / 10) + fake()->numberBetween(-2, 2)));

            [$behavior, $commitment, $memorization, $tajweed] = [$score(), $score(), $score(), $score()];

            Evaluation::create([
                'student_id' => $enrollment->student_id,
                'course_circle_id' => $enrollment->course_circle_id,
                'period' => EvaluationPeriod::Monthly,
                'period_start' => $start->toDateString(),
                'period_end' => $start->copy()->endOfMonth()->toDateString(),
                'behavior' => $behavior,
                'commitment' => $commitment,
                'memorization' => $memorization,
                'tajweed' => $tajweed,
                'total' => $behavior + $commitment + $memorization + $tajweed,
                'teacher_id' => $this->teachers->get($enrollment->course_circle_id)?->id,
                'notes' => fake()->boolean(25) ? fake()->randomElement(self::EVALUATION_NOTES) : null,
            ]);
        }
    }

    /**
     * أربعة وسوم، ثلاثةٌ منها مشتقّة من البيانات المبذورة: من أتمّ جزء عمّ، ومن غاب
     * ثلاثَ مرّاتٍ فأكثر، وأعلى عُشر الطلاب نقاطاً. والرابع (حالة اجتماعية) يضعه المشرف بيده.
     */
    private function seedTags(Institute $institute): void
    {
        $tag = fn (string $slug, string $name, string $color): Tag => Tag::create([
            'institute_id' => $institute->id,
            'name' => $name,
            'slug' => $slug,
            'color' => $color,
        ]);

        $amma = $tag('amma-hafiz', 'حافظ لجزء عمّ', '#7c3aed');
        $follow = $tag('needs-follow-up', 'يحتاج متابعة', '#d97706');
        $excelling = $tag('excelling', 'متفوّق', '#16a34a');
        $social = $tag('social-case', 'حالة اجتماعية', '#2563eb');

        $students = Student::query()->where('institute_id', $institute->id)->get()->keyBy('id');

        $ammaIds = StudentCurriculumProgress::query()
            ->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->whereHas('curriculumItem', fn ($query) => $query->where('code', 'juz-30'))
            ->pluck('student_id');

        $followIds = Attendance::query()
            ->where('status', AttendanceStatus::Absent)
            ->selectRaw('student_id, COUNT(*) as absences')
            ->groupBy('student_id')
            ->havingRaw('COUNT(*) >= 3')
            ->pluck('student_id');

        $excellingIds = MemorizationLog::query()
            ->selectRaw('student_id, SUM(points) as total')
            ->groupBy('student_id')
            ->orderByDesc('total')
            ->limit((int) ceil($students->count() / 10))
            ->pluck('student_id');

        $socialIds = $students->keys()->shuffle()->take((int) ceil($students->count() / 20));

        foreach ([[$amma, $ammaIds], [$follow, $followIds], [$excelling, $excellingIds], [$social, $socialIds]] as [$tag, $ids]) {
            foreach ($ids as $id) {
                $students->get($id)?->tags()->syncWithoutDetaching([$tag->id]);
            }
        }
    }

    /**
     * واصفتان للطالب (المدرسة وفصيلة الدم) وواحدة للأستاذ (الرواية المُجاز بها)، وقيمها
     * لكل سجلّ — فتظهر في استمارة التسجيل وفي ملف الطالب معاً.
     */
    private function seedCustomFields(Institute $institute): void
    {
        $field = fn (string $entity, string $key, string $label, CustomFieldType $type, ?array $options = null, int $order = 0): CustomField => CustomField::create([
            'institute_id' => $institute->id,
            'entity' => $entity,
            'key' => $key,
            'label' => $label,
            'type' => $type,
            'options' => $options,
            'group' => $entity === 'student' ? 'بيانات إضافية' : null,
            'is_required' => false,
            'is_active' => true,
            'sort_order' => $order,
        ]);

        $school = $field('student', 'school_name', 'المدرسة', CustomFieldType::Text, order: 0);
        $blood = $field('student', 'blood_type', 'فصيلة الدم', CustomFieldType::Select, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], 1);
        $riwaya = $field('teacher', 'riwaya', 'الرواية المُجاز بها', CustomFieldType::Select, ['حفص عن عاصم', 'ورش عن نافع', 'قالون عن نافع'], 0);

        foreach (Student::query()->where('institute_id', $institute->id)->get() as $student) {
            $this->setValue($school, $student, $this->schoolOf($student));

            if (fake()->boolean(70)) {
                $this->setValue($blood, $student, fake()->randomElement(['A+', 'B+', 'O+', 'O+', 'AB+', 'A-', 'O-']));
            }
        }

        foreach (Teacher::query()->where('institute_id', $institute->id)->get() as $teacher) {
            $this->setValue($riwaya, $teacher, 'حفص عن عاصم');
        }
    }

    private function schoolOf(Student $student): string
    {
        $grade = (string) $student->grade_level;

        return match (true) {
            str_contains($grade, 'ثانوي') => self::SCHOOLS['ثانوي'],
            str_contains($grade, 'الابتدائي') => self::SCHOOLS['ابتدائي'],
            default => self::SCHOOLS['متوسط'],
        };
    }

    private function setValue(CustomField $field, Student|Teacher $record, string $value): void
    {
        CustomFieldValue::create([
            'custom_field_id' => $field->id,
            'entity_type' => $record->getMorphClass(),
            'entity_id' => $record->id,
            'value' => $value,
        ]);
    }
}
