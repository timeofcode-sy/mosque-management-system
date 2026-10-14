<?php

namespace App\Actions;

use App\Enums\CourseStatus;
use App\Enums\CustomFieldType;
use App\Enums\Gender;
use App\Enums\GuardianRelation;
use App\Enums\MemorizationType;
use App\Enums\StudentStatus;
use App\Enums\TeacherRole;
use App\Enums\TeacherStatus;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\CustomField;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\Shift;
use App\Models\Teacher;
use App\Support\Quran;
use App\Support\SyncRecorder;
use Database\Seeders\CurriculumSeeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * ضمُّ معهدٍ كامل من مصنّف استيراد: المعهد ودورته الجارية، والدوامات، والأساتذة، والحلقات
 * وتشغيلها في الدورة، والواصفات، والطلاب بأوليائهم ومحفوظاتهم وتسجيلهم في حلقاتهم.
 * بنية المصنّف في docs/IMPORT.md.
 *
 * يجري على مرحلتين: قراءةٌ تتحقّق من المصنّف كلِّه ولا تكتب شيئاً، ثم كتابةٌ في معاملةٍ واحدة
 * تُلغى كلُّها عند أول خطأ — فلا يبقى معهدٌ نصفُ مستورد. والكتابة تمرّ بالأفعال نفسها التي
 * تستعملها اللوحة (SaveStudentRegistration وEnrollStudent وRunCircleInCourse…)، فتُولَّد
 * الحسابات وتُحسب الأجزاء كما لو سُجّل كلُّ طالبٍ بالاستمارة.
 *
 * التسجيل في change_log معطّلٌ أثناء الكتابة ثم يُردم مرّةً في آخرها، كما يفعل البذر.
 *
 * والسور المحفوظة قبل الالتحاق (سورٌ لا أجزاءٌ كاملة: الكهف، يس…) تُكتب تسميعَ «حفظ» مؤرَّخاً
 * قبل بداية الدورة وبلا نقاط: منه تُبنى خريطة المصحف ونسب الأجزاء، ولا يدخل إحصاءات
 * الدورة ولا نقاطها لأنها تُجمع داخل تواريخ الدورة.
 */
class ImportInstitute
{
    public const SHEET_INSTITUTE = 'المعهد';

    public const SHEET_SHIFTS = 'الدوامات';

    public const SHEET_TEACHERS = 'الأساتذة';

    public const SHEET_CIRCLES = 'الحلقات';

    public const SHEET_CUSTOM_FIELDS = 'الواصفات';

    public const SHEET_STUDENTS = 'الطلاب';

    private const WEEKDAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    /** @var list<string> */
    private array $errors = [];

    /** @var list<string> */
    private array $warnings = [];

    public function __construct(
        private readonly SaveShift $saveShift,
        private readonly RunCircleInCourse $runCircle,
        private readonly SaveStudentRegistration $saveStudent,
        private readonly EnrollStudent $enrollStudent,
        private readonly RefreshJuzProgress $juzProgress,
        private readonly SyncRecorder $recorder,
    ) {}

    /**
     * @param  array<string, list<list<?string>>>  $sheets  أوراق المصنّف كما يقرؤها XlsxReader
     * @param  bool  $dryRun  يكتب كلَّ شيء ثم يتراجع — أصدقُ تحقّقٍ لأنه يمرّ بالقيود كلِّها
     * @param  bool  $withoutPasswords  الحسابات بأسماء دخولها وبلا كلمات حتى تُصدَر (accounts:issue-passwords)
     * @return array{errors: list<string>, warnings: list<string>, counts: array<string, int>, institute: ?Institute}
     */
    public function handle(array $sheets, bool $dryRun = false, bool $withoutPasswords = false): array
    {
        $this->errors = [];
        $this->warnings = [];

        $plan = $this->parse($sheets);

        if ($this->errors !== []) {
            return $this->result([], null);
        }

        DB::beginTransaction();

        try {
            $write = fn (): array => $this->recorder->without(fn (): array => $this->write($plan));
            [$counts, $institute] = $withoutPasswords ? GenerateAccount::withoutPasswords($write) : $write();

            if ($this->errors === []) {
                Artisan::call('sync:backfill-change-log');
            }
        } catch (Throwable $exception) {
            DB::rollBack();

            throw $exception;
        }

        if ($this->errors !== [] || $dryRun) {
            DB::rollBack();

            return $this->result($this->errors === [] ? $counts : [], null);
        }

        DB::commit();

        return $this->result($counts, $institute);
    }

    /**
     * @param  array<string, int>  $counts
     * @return array{errors: list<string>, warnings: list<string>, counts: array<string, int>, institute: ?Institute}
     */
    private function result(array $counts, ?Institute $institute): array
    {
        return ['errors' => $this->errors, 'warnings' => $this->warnings, 'counts' => $counts, 'institute' => $institute];
    }

    // ------------------------------------------------------------------ القراءة

    /**
     * @param  array<string, list<list<?string>>>  $sheets
     * @return array<string, mixed>
     */
    private function parse(array $sheets): array
    {
        $institute = collect($this->table($sheets, self::SHEET_INSTITUTE, ['البند', 'القيمة']))
            ->mapWithKeys(fn (array $row) => [(string) $row['البند'] => $row['القيمة']]);

        $name = trim((string) $institute->get('الاسم'));

        if ($name === '') {
            $this->errors[] = 'ورقة «المعهد»: الاسم مطلوب.';
        } elseif (Institute::query()->where('name', $name)->exists()) {
            $this->errors[] = "معهدٌ باسم «{$name}» موجودٌ أصلاً — الاستيراد ينشئ معهداً جديداً ولا يدمج في قائم.";
        }

        $settings = $institute->get('الإعدادات');
        $settings = $settings === null ? [] : json_decode($settings, true);

        if (! is_array($settings)) {
            $this->errors[] = 'ورقة «المعهد»: «الإعدادات» ليست JSON صالحاً.';
        }

        $plan = [
            'institute' => [
                'name' => $name,
                'short_name' => $institute->get('الاسم المختصر'),
                'settings' => is_array($settings) ? $settings : [],
            ],
            'course' => [
                'name' => $institute->get('الدورة') ?: 'دورة '.Carbon::today()->year,
                'starts_on' => $this->date($institute->get('بداية الدورة'), 'المعهد: بداية الدورة') ?? Carbon::today()->toDateString(),
                'ends_on' => $this->date($institute->get('نهاية الدورة'), 'المعهد: نهاية الدورة') ?? Carbon::today()->addMonths(3)->toDateString(),
            ],
        ];

        $plan['shifts'] = [];

        foreach ($this->table($sheets, self::SHEET_SHIFTS, ['الدوام', 'البداية', 'النهاية', 'الأيام']) as $row) {
            $where = "الدوامات سطر {$row['#']}";
            $weekdays = [];

            foreach ($this->list($row['الأيام']) as $day) {
                $index = array_search($day, self::WEEKDAYS, true);
                $index === false ? $this->errors[] = "{$where}: يومٌ غير معروف «{$day}»." : $weekdays[] = $index;
            }

            $plan['shifts'][$this->key($row['الدوام'])] = [
                'name' => $this->required($row, 'الدوام', $where),
                'starts_at' => $this->required($row, 'البداية', $where),
                'ends_at' => $this->required($row, 'النهاية', $where),
                'sort_order' => (int) ($row['الترتيب'] ?? 0),
                'weekdays' => $weekdays,
            ];
        }

        $plan['teachers'] = [];

        foreach ($this->table($sheets, self::SHEET_TEACHERS, ['الاسم']) as $row) {
            $name = $this->required($row, 'الاسم', "الأساتذة سطر {$row['#']}");
            $plan['teachers'][$this->key($name)] = ['name' => $name, 'phone' => $this->phone($row['الجوال'] ?? null)];
        }

        $plan['circles'] = [];

        foreach ($this->table($sheets, self::SHEET_CIRCLES, ['الحلقة', 'الدوام', 'الأستاذ']) as $row) {
            $where = "الحلقات سطر {$row['#']}";
            $shift = $this->key($row['الدوام']);
            $teacher = $this->key($row['الأستاذ']);

            if ($shift !== '' && ! isset($plan['shifts'][$shift])) {
                $this->errors[] = "{$where}: الدوام «{$row['الدوام']}» ليس في ورقة الدوامات.";
            }

            if ($teacher !== '' && ! isset($plan['teachers'][$teacher])) {
                $this->errors[] = "{$where}: الأستاذ «{$row['الأستاذ']}» ليس في ورقة الأساتذة.";
            }

            $plan['circles'][$this->key($row['الحلقة'])] = [
                'name' => $this->required($row, 'الحلقة', $where),
                'shift' => $shift,
                'teacher' => $teacher,
                'capacity' => filled($row['الطاقة'] ?? null) ? (int) $row['الطاقة'] : null,
                'is_active' => ($row['مفعّلة'] ?? null) === null || $this->yes($row['مفعّلة']),
                'sort_order' => (int) ($row['الترتيب'] ?? 0),
            ];
        }

        $plan['custom_fields'] = [];

        if (isset($sheets[self::SHEET_CUSTOM_FIELDS])) {
            foreach ($this->table($sheets, self::SHEET_CUSTOM_FIELDS, ['العنوان', 'النوع']) as $row) {
                $where = "الواصفات سطر {$row['#']}";
                $type = CustomFieldType::tryFrom((string) $row['النوع']);

                if ($type === null) {
                    $this->errors[] = "{$where}: نوعٌ غير معروف «{$row['النوع']}».";
                }

                $label = $this->required($row, 'العنوان', $where);
                $plan['custom_fields'][$label] = [
                    'label' => $label,
                    'key' => ($row['المفتاح'] ?? null) ?: Str::slug($label, '_') ?: 'field_'.$row['#'],
                    'type' => $type ?? CustomFieldType::Text,
                    'options' => $this->list($row['الخيارات'] ?? null) ?: null,
                    'group' => $row['المجموعة'] ?? null,
                    'is_required' => $this->yes($row['مطلوبة'] ?? null),
                ];
            }
        }

        $plan['students'] = [];

        foreach ($this->table($sheets, self::SHEET_STUDENTS, ['الاسم', 'اسم الأب', 'الكنية']) as $row) {
            $where = 'الطلاب '.($row['المرجع'] ?? "سطر {$row['#']}");
            $circle = $this->key($row['الحلقة'] ?? null);

            if ($circle !== '' && ($plan['circles'][$circle]['shift'] ?? '') === '') {
                $this->errors[] = isset($plan['circles'][$circle])
                    ? "{$where}: الحلقة «{$row['الحلقة']}» لا تعمل في الدورة (بلا دوام)."
                    : "{$where}: الحلقة «{$row['الحلقة']}» ليست في ورقة الحلقات.";
            }

            $gender = match ($row['الجنس'] ?? null) {
                null, 'ذكر' => Gender::Male,
                'أنثى' => Gender::Female,
                default => null,
            };

            if ($gender === null) {
                $this->errors[] = "{$where}: الجنس «{$row['الجنس']}» ليس «ذكر» أو «أنثى».";
            }

            $juz = [];

            foreach ($this->list($row['الأجزاء المحفوظة'] ?? null) as $number) {
                ctype_digit($number) && (int) $number >= 1 && (int) $number <= 30
                    ? $juz[] = (int) $number
                    : $this->errors[] = "{$where}: «{$number}» ليس رقم جزء (1 إلى 30).";
            }

            $surahs = [];

            foreach ($this->list($row['السور المحفوظة'] ?? null) as $surah) {
                ($number = $this->surah($surah)) === null
                    ? $this->errors[] = "{$where}: «{$surah}» ليست سورة."
                    : $surahs[] = $number;
            }

            $plan['students'][] = [
                'where' => $where,
                // رمزٌ حرٌّ يتشاركه الإخوة: نفس «رمز الأب» ⇐ سجلُّ أبٍ واحد، ونفس «رمز الأم» ⇐ سجلُّ أمٍّ واحد.
                'codes' => [
                    GuardianRelation::Father->value => trim((string) ($row['رمز الأب'] ?? '')),
                    GuardianRelation::Mother->value => trim((string) ($row['رمز الأم'] ?? '')),
                ],
                'attributes' => [
                    'first_name' => $this->required($row, 'الاسم', $where),
                    'father_name' => $this->required($row, 'اسم الأب', $where),
                    'family_name' => $this->required($row, 'الكنية', $where),
                    'gender' => ($gender ?? Gender::Male)->value,
                    'birth_date' => $this->date($row['تاريخ الولادة'] ?? null, "{$where}: تاريخ الولادة"),
                    'grade_level' => $row['الصف'] ?? null,
                    'student_job' => $row['عمل الطالب'] ?? null,
                    'phone' => $this->phone($row['جوال الطالب'] ?? null),
                    'current_address' => $row['العنوان'] ?? null,
                    'notes' => $row['ملاحظات'] ?? null,
                    'status' => StudentStatus::Active->value,
                ],
                'father' => [
                    'occupation' => $row['عمل الأب'] ?? null,
                    'phone' => $this->phone($row['جوال الأب'] ?? null),
                ],
                'father_is_alive' => ! $this->yes($row['الأب متوفى'] ?? null),
                'mother' => [
                    'first_name' => $row['اسم الأم'] ?? null,
                    'family_name' => $row['كنية الأم'] ?? null,
                    'occupation' => $row['عمل الأم'] ?? null,
                    'phone' => $this->phone($row['جوال الأم'] ?? null),
                ],
                'circle' => $circle,
                'juz' => $juz,
                'surahs' => $surahs,
                'others' => $this->list($row['محفوظات أخرى'] ?? null),
                'custom_fields' => collect($plan['custom_fields'])
                    ->mapWithKeys(fn (array $field, string $label) => [$label => $row[$label] ?? null])
                    ->filter(fn ($value) => filled($value))
                    ->all(),
            ];
        }

        return $plan;
    }

    /**
     * صفوف ورقةٍ بأسماء أعمدتها (سطرها الأول)، بلا الصفوف الفارغة. `#` رقم السطر في الورقة.
     *
     * @param  array<string, list<list<?string>>>  $sheets
     * @param  list<string>  $required
     * @return list<array<string, ?string>>
     */
    private function table(array $sheets, string $name, array $required): array
    {
        if (! isset($sheets[$name])) {
            $this->errors[] = "المصنّف بلا ورقة «{$name}».";

            return [];
        }

        $rows = $sheets[$name];
        $headers = array_map(fn (?string $header) => trim((string) $header), $rows[0] ?? []);

        foreach (array_diff($required, $headers) as $missing) {
            $this->errors[] = "ورقة «{$name}» بلا عمود «{$missing}».";
        }

        $table = [];

        foreach (array_slice($rows, 1) as $index => $cells) {
            $cells = array_map(fn (?string $cell) => ($cell = trim((string) $cell)) === '' ? null : $cell, $cells);

            if (array_filter($cells, fn (?string $cell) => $cell !== null) === []) {
                continue;
            }

            $row = ['#' => (string) ($index + 2)];

            foreach ($headers as $column => $header) {
                if ($header !== '') {
                    $row[$header] = $cells[$column] ?? null;
                }
            }

            $table[] = $row;
        }

        return $table;
    }

    /**
     * @param  array<string, ?string>  $row
     */
    private function required(array $row, string $column, string $where): string
    {
        $value = trim((string) ($row[$column] ?? ''));

        if ($value === '') {
            $this->errors[] = "{$where}: «{$column}» مطلوب.";
        }

        return $value;
    }

    /**
     * تاريخٌ بصيغة 2014-05-11، أو سنةٌ وحدها، أو رقمٌ تسلسلي كما يحفظ Excel ما كُتب تاريخاً.
     */
    private function date(?string $value, string $where): ?string
    {
        if ($value === null || trim($value) === '') {
            return null;
        }

        $value = trim($value);

        if (preg_match('/^\d{4}$/', $value)) {
            return "{$value}-01-01";
        }

        if (preg_match('/^\d{4}-\d{2}-\d{2}/', $value) && strtotime(substr($value, 0, 10)) !== false) {
            return substr($value, 0, 10);
        }

        if (is_numeric($value) && (float) $value > 1 && (float) $value < 100000) {
            return Carbon::create(1899, 12, 30)->addDays((int) $value)->toDateString();
        }

        $this->errors[] = "{$where}: «{$value}» ليس تاريخاً (اكتبه 2014-05-11).";

        return null;
    }

    /**
     * رقمُ جوالٍ كما يُحفظ: أرقامٌ فقط، والصفر الذي يُسقطه Excel من الرقم يُعاد.
     */
    private function phone(?string $value): ?string
    {
        $digits = preg_replace('/\D/', '', (string) $value);

        if ($digits === '') {
            return null;
        }

        if (strlen($digits) === 9 && str_starts_with($digits, '9')) {
            $digits = "0{$digits}";
        }

        if (! preg_match('/^09\d{8}$/', $digits)) {
            $this->warnings[] = "رقمٌ ليس جوالاً سورياً من عشرة أرقام، حُفظ كما هو: {$value}";
        }

        return $digits;
    }

    /**
     * @return list<string>
     */
    private function list(?string $value): array
    {
        return array_values(array_filter(array_map('trim', preg_split('/[،,]/u', (string) $value)), fn (string $item) => $item !== ''));
    }

    /**
     * رقم سورةٍ من اسمها («الكهف»، «يس») أو رقمها.
     */
    private function surah(string $value): ?int
    {
        if (ctype_digit($value)) {
            return Quran::ayahs((int) $value) > 0 ? (int) $value : null;
        }

        static $names = null;
        $names ??= collect(range(1, 114))->mapWithKeys(fn (int $number) => [$this->arabicKey(Quran::name($number)) => $number])->all();

        return $names[$this->arabicKey($value)] ?? $names[$this->arabicKey('ال'.$value)] ?? null;
    }

    private function arabicKey(string $value): string
    {
        return str_replace(['أ', 'إ', 'آ', 'ة', 'ى'], ['ا', 'ا', 'ا', 'ه', 'ي'], $this->key($value));
    }

    /**
     * اسم أبٍ مجهول كُتب مكانه حرفٌ أو «بن»: يبقى في اسم الطالب، ولا يُنشأ له وليُّ أمرٍ بلا اسم.
     */
    private function unknownName(string $name): bool
    {
        return mb_strlen($this->key($name)) < 2 || in_array($this->key($name), ['بن', 'ابن', '؟', '-', '—'], true);
    }

    private function yes(?string $value): bool
    {
        return in_array(trim((string) $value), ['نعم', '1', 'TRUE', 'true', 'yes'], true);
    }

    private function key(?string $value): string
    {
        return (string) preg_replace('/\s+/u', ' ', trim((string) $value));
    }

    // ------------------------------------------------------------------ الكتابة

    /**
     * @param  array<string, mixed>  $plan
     * @return array{0: array<string, int>, 1: Institute}
     */
    private function write(array $plan): array
    {
        $institute = Institute::create([...$plan['institute'], 'is_active' => true]);

        $course = Course::create([
            ...$plan['course'],
            'institute_id' => $institute->id,
            'status' => CourseStatus::Active,
            'is_current' => true,
        ]);

        $shifts = collect($plan['shifts'])->map(fn (array $shift): Shift => $this->saveShift->handle(
            $course,
            [...collect($shift)->except('weekdays')->all(), 'is_active' => true],
            $shift['weekdays'],
        ));

        $teachers = collect($plan['teachers'])->map(fn (array $teacher): Teacher => Teacher::create([
            'institute_id' => $institute->id,
            'display_name' => $teacher['name'],
            'phone' => $teacher['phone'],
            'status' => TeacherStatus::Active,
        ]));

        /** @var array<string, CourseCircle> $courseCircles */
        $courseCircles = [];

        foreach ($plan['circles'] as $key => $plannedCircle) {
            $circle = Circle::create([
                'institute_id' => $institute->id,
                'name' => $plannedCircle['name'],
                'sort_order' => $plannedCircle['sort_order'],
                'is_active' => $plannedCircle['is_active'],
            ]);

            if ($plannedCircle['shift'] === '') {
                continue;
            }

            $courseCircles[$key] = $this->runCircle->handle($course, $circle, $shifts[$plannedCircle['shift']], null, $plannedCircle['capacity']);

            if ($plannedCircle['teacher'] !== '') {
                CourseCircleTeacher::create([
                    'course_circle_id' => $courseCircles[$key]->id,
                    'teacher_id' => $teachers[$plannedCircle['teacher']]->id,
                    'role' => TeacherRole::Main,
                    'joined_on' => $course->starts_on,
                ]);
            }
        }

        $customFields = collect($plan['custom_fields'])->values()->map(fn (array $field, int $index): CustomField => CustomField::create([
            ...$field,
            'institute_id' => $institute->id,
            'entity' => 'student',
            'is_active' => true,
            'sort_order' => $index,
        ]))->keyBy('label');

        $items = $this->curriculumItems();
        /** @var array<string, array<string, array{id: int, details: array<string, ?string>}>> صلة القرابة ← الرمز ← السجلّ المشترك */
        $shared = [];
        $enrolled = 0;

        foreach ($plan['students'] as $planned) {
            $memorized = [];

            foreach ($planned['juz'] as $juz) {
                $memorized[] = $items["juz-{$juz}"];
            }

            foreach ($planned['others'] as $name) {
                isset($items[$name])
                    ? $memorized[] = $items[$name]
                    : $this->errors[] = "{$planned['where']}: لا محفوظ في المناهج العامة باسم «{$name}».";
            }

            $siblingIds = [];

            foreach ($planned['codes'] as $relation => $code) {
                $known = $code === '' ? null : $shared[$relation][$code] ?? null;

                if ($known === null) {
                    continue;
                }

                $siblingIds[$relation] = $known['id'];

                if ($known['details'] !== $planned[$relation]) {
                    $this->warnings[] = "{$planned['where']}: بيانات صاحب الرمز {$code} تخالف ما سُجّل مع أخيه — أُبقي ما لم يُترك فارغاً.";
                }
            }

            $guardians = [GuardianRelation::Mother->value => $planned['mother']];

            if ($this->unknownName($planned['attributes']['father_name'])) {
                $this->warnings[] = "{$planned['where']}: اسم الأب غير معروف — لم يُنشأ له وليُّ أمر.";
            } else {
                $guardians[GuardianRelation::Father->value] = [
                    'first_name' => $planned['attributes']['father_name'],
                    'family_name' => $planned['attributes']['family_name'],
                    ...$planned['father'],
                ];
            }

            $student = $this->saveStudent->handle(
                institute: $institute,
                attributes: $planned['attributes'],
                guardians: $guardians,
                memorizedItemIds: $memorized,
                customFieldValues: collect($planned['custom_fields'])
                    ->mapWithKeys(fn (string $value, string $label) => [$customFields[$label]->id => $value])
                    ->all(),
                siblingGuardianIds: $siblingIds,
            );

            foreach ($planned['surahs'] as $surah) {
                MemorizationLog::create([
                    'student_id' => $student->id,
                    'date' => $course->starts_on->copy()->subDay()->toDateString(),
                    'type' => MemorizationType::Hifz,
                    'from_surah' => $surah,
                    'from_ayah' => 1,
                    'to_surah' => $surah,
                    'to_ayah' => Quran::ayahs($surah),
                    'juz' => Quran::juzOfSurah($surah),
                    'points' => 0,
                    'notes' => 'حفظٌ سابقٌ للالتحاق — من بيانات التسجيل.',
                ]);
            }

            if ($planned['surahs'] !== []) {
                $this->juzProgress->handle($student);
            }

            $student->load('guardians');

            if (! $planned['father_is_alive']) {
                $student->father()?->update(['is_alive' => false]);
            }

            foreach ($planned['codes'] as $relation => $code) {
                $guardian = $relation === GuardianRelation::Father->value ? $student->father() : $student->mother();

                if ($code !== '' && $guardian !== null && ! isset($shared[$relation][$code])) {
                    $shared[$relation][$code] = ['id' => $guardian->id, 'details' => $planned[$relation]];
                }
            }

            if ($planned['circle'] === '') {
                continue;
            }

            try {
                $this->enrollStudent->handle($student, $courseCircles[$planned['circle']]);
                $enrolled++;
            } catch (RuntimeException $exception) {
                $this->errors[] = "{$planned['where']}: لم يُسجَّل في «{$courseCircles[$planned['circle']]->circle->name}» — {$exception->getMessage()}";
            }
        }

        return [[
            'أوقات الدوام' => $shifts->count(),
            'الأساتذة' => $teachers->count(),
            'الحلقات' => count($plan['circles']),
            'الحلقات المفعّلة في الدورة' => count($courseCircles),
            'الطلاب' => count($plan['students']),
            'المسجّلون في حلقات' => $enrolled,
            'أولياء الأمور' => $institute->guardians()->count(),
        ], $institute];
    }

    /**
     * بنود المناهج العامة: الأجزاء برموزها (juz-30) وما سواها بأسمائها. المناهج العامة تُزرع
     * هنا إن غابت، فخادم الإنتاج لا يُبذر إلا الأدوار (DEPLOYMENT.md §ب.6).
     *
     * @return array<string, int>
     */
    private function curriculumItems(): array
    {
        if (! Curriculum::query()->whereNull('institute_id')->where('slug', 'quran')->exists()) {
            (new CurriculumSeeder)->run();
            $this->warnings[] = 'المناهج العامة (القرآن والحديث والمتون) لم تكن مزروعة — زُرعت.';
        }

        $items = CurriculumItem::query()
            ->whereHas('curriculum', fn ($query) => $query->whereNull('institute_id'))
            ->with('curriculum:id,slug')
            ->get();

        return $items->mapWithKeys(fn (CurriculumItem $item) => [$item->name => $item->id])
            ->merge($items->where('curriculum.slug', 'quran')->mapWithKeys(fn (CurriculumItem $item) => [$item->code => $item->id]))
            ->all();
    }
}
