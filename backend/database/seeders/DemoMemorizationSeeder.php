<?php

namespace Database\Seeders;

use App\Actions\SaveStudentCurriculumProgress;
use App\Enums\AttendanceStatus;
use App\Enums\CourseStatus;
use App\Enums\CurriculumType;
use App\Enums\MemorizationType;
use App\Enums\PointReason;
use App\Enums\ProgressStatus;
use App\Enums\RecitationGrade;
use App\Enums\TeacherRole;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Course;
use App\Models\CourseCircleTeacher;
use App\Models\CurriculumItem;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\Teacher;
use App\Models\User;
use App\Support\PointsSettings;
use App\Support\Quran;
use Database\Seeders\Support\RecitationWalker;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * محفوظات الطلاب وتسميعاتهم: ما يجعل تطبيقات الطالب وولي الأمر والأستاذ تُفتح على
 * بياناتٍ كاملة بدل شاشات فارغة.
 *
 * - **تسميعٌ فعليّ بمدى سورٍ وآيات** لا أسطرٌ مجرّدة: خريطة المصحف وتغطية الآيات واقتراح
 *   المقطع التالي كلُّها تُبنى من `from_surah … to_ayah`، وبدونها تبقى الخريطة بيضاء.
 * - **تاريخٌ سابق للدورة**: الطالب لا يبدأ من الصفر، فلكلٍّ محفوظٌ يناسب عمره، ثم يكمل
 *   في حصص الأسبوعين الأخيرين من حيث وقف.
 * - **تقدّم المناهج**: الأجزاء من الحفظ نفسه (جزءٌ مكتمل ⇒ «محفوظ»)، والأربعون النبوية
 *   والمتون بدرجاتٍ متفاوتة.
 *
 * النقاط تُحسب بإعدادات المعهد وتُجمَّد في الصفّ كما يفعل `SaveRecitation` و
 * `SaveStudentCurriculumProgress` على الخادم.
 */
class DemoMemorizationSeeder extends Seeder
{
    /** من ختم القرآن كلَّه — مرحلةٌ تلي مراحل `RecitationWalker` */
    private const KHATM = 'khatm';

    /**
     * حصّة كل مرحلة من الطلاب (جزء عمّ يأخذ الباقي ≈ 60%) — ترتيبها من الأعلى إلى الأدنى،
     * وبه يُوزَّع الطلاب: الأكبر سناً في المراحل الأعلى.
     *
     * @var array<string, float>
     */
    private const STAGE_SHARES = [
        self::KHATM => 0.01,
        RecitationWalker::QURAN => 0.10,
        RecitationWalker::MUNJIYAT => 0.05,
        RecitationWalker::QAD_SAMI => 0.05,
        RecitationWalker::TABARAK => 0.20,
    ];

    /**
     * أقلّ مدة (بالأيام) بين تسجيل الطالب وبدء الدورة لكل مرحلة — من بلغ القرآن من بدايته
     * لم يبدأ بالأمس. تُرفع بها تواريخ التسجيل المتأخرة فقط.
     *
     * @var array<string, int>
     */
    private const MIN_REGISTERED_DAYS = [
        RecitationWalker::AMMA => 14,
        RecitationWalker::TABARAK => 300,
        RecitationWalker::QAD_SAMI => 450,
        RecitationWalker::MUNJIYAT => 600,
        RecitationWalker::QURAN => 800,
        self::KHATM => 1400,
    ];

    /**
     * سعة الطالب في الأربعين النبوية والمتون بحسب مرحلته في القرآن.
     *
     * @var array<string, float>
     */
    private const ABILITY = [
        RecitationWalker::AMMA => 0.1,
        RecitationWalker::TABARAK => 0.3,
        RecitationWalker::QAD_SAMI => 0.5,
        RecitationWalker::MUNJIYAT => 0.7,
        RecitationWalker::QURAN => 0.9,
        self::KHATM => 1.0,
    ];

    /**
     * ملاحظات الأستاذ على التسميع — أغلبه بلا ملاحظة، كما في الحلقة.
     *
     * @var array<int, string>
     */
    private const RECITATION_NOTES = [
        'يحتاج إلى مراجعة المقطع قبل الحصة القادمة.',
        'أداءٌ متميّز وتجويدٌ جيّد.',
        'تردّد في مواضع التشابه.',
        'ثبّت الحفظ ما شاء الله، وننتقل إلى المقطع التالي.',
        'أخطاء في المدود، يُعاد في الحصة القادمة.',
    ];

    /**
     * @var array<int, string>
     */
    private const PROGRESS_NOTES = [
        'سمّعه كاملاً على الأستاذ.',
        'مستمرّ بانتظام وحفظه متين.',
        'يحتاج إلى مراجعةٍ أسبوعية.',
        'أتمّه في وقتٍ أبكر من المتوقع.',
    ];

    private PointsSettings $settings;

    private User $admin;

    /** @var Collection<int, Teacher> أستاذ كل حلقة، بمفتاح course_circle_id */
    private Collection $teachers;

    /** @var Collection<int, CurriculumItem> أجزاء القرآن بمفتاح رقم الجزء */
    private Collection $juzItems;

    /** @var array<string, Collection<int, CurriculumItem>> بنود الحديث والمتون مرتّبةً */
    private array $items = [];

    private Carbon $courseStart;

    public function run(Institute $institute, User $admin): void
    {
        $this->settings = PointsSettings::for($institute);
        $this->admin = $admin;

        $course = Course::query()
            ->where('institute_id', $institute->id)
            ->where('status', CourseStatus::Active)
            ->firstOrFail();

        $this->courseStart = Carbon::parse($course->starts_on);
        $this->teachers = $this->mainTeachers($course);
        $this->loadCurricula();

        /** حاضرو الحصص وحدهم يُسمّعون — الغائب لا يُفترض له تسميع */
        $attended = Attendance::query()
            ->whereIn('status', [AttendanceStatus::Present, AttendanceStatus::Late])
            ->whereHas('attendanceSession.courseCircle', fn ($query) => $query->where('course_id', $course->id))
            ->with('attendanceSession')
            ->get()
            ->sortBy(fn (Attendance $attendance) => Carbon::parse($attendance->attendanceSession->session_date)->toDateString())
            ->groupBy('student_id');

        $students = Student::query()->where('institute_id', $institute->id)->get();
        $stages = $this->assignStages($students);

        foreach ($students as $student) {
            [$stage, $fraction] = $stages[$student->id];

            $this->seedStudent($student, $stage, $fraction, $attended->get($student->id, new Collection));
        }
    }

    /**
     * يوزّع الطلاب على مراحل الحفظ: 60% ما زالوا في جزء عمّ، و20% في تبارك، و5% في «قد سمع»،
     * و5% في المنجيات، و10% في القرآن من بدايته، وواحدٌ فقط ختم. ويُقدَّم الأكبر سناً إلى
     * المراحل الأعلى (مع تفاوتٍ بسيط، فليس كل كبيرٍ سابقاً ولا كل صغيرٍ متأخراً).
     *
     * @param  Collection<int, Student>  $students
     * @return array<int, array{string, float}> [student_id => [المرحلة، موضعه فيها من 0 إلى 1]]
     */
    private function assignStages(Collection $students): array
    {
        $total = $students->count();

        $counts = collect(self::STAGE_SHARES)->map(fn (float $share) => (int) round($total * $share))->all();
        $counts[self::KHATM] = max(1, $counts[self::KHATM]);
        $counts[RecitationWalker::AMMA] = max(0, $total - array_sum($counts));

        $ranked = $students
            ->sortByDesc(fn (Student $student) => Carbon::parse($student->birth_date)->age + fake()->numberBetween(-2, 2))
            ->values();

        $assigned = [];
        $next = 0;

        foreach ($counts as $stage => $count) {
            for ($i = 0; $i < $count && $next < $total; $i++) {
                $assigned[$ranked[$next++]->id] = [$stage, fake()->randomFloat(2, 0.05, 0.95)];
            }
        }

        return $assigned;
    }

    /**
     * @param  Collection<int, Attendance>  $attendances  حصص الطالب التي حضرها، من الأقدم
     */
    private function seedStudent(Student $student, string $stage, float $fraction, Collection $attendances): void
    {
        $walker = new RecitationWalker;

        // الخطة كلّها حتى موضع الطالب اليوم، ثم تُقسَم بين ما سبق الدورة وحصصها الأخيرة.
        $plan = $stage === self::KHATM ? $walker->walkToEnd() : $walker->walkTo($stage, $fraction);
        $lessons = $this->planLessons($attendances);

        // الحفظ الجديد في الحصص هو آخر الخطة؛ والخاتم يراجع في أسبوعيه الأخيرين ولا يحفظ.
        $hifzLessons = count(array_filter($lessons, fn (array $lesson) => $lesson['type'] === MemorizationType::Hifz));
        $inSessions = $stage === self::KHATM ? 0 : min($hifzLessons, count($plan));

        $this->ensureRegisteredEarlyEnough($student, $stage);

        /** @var array<int, array{surah: int, from: int, to: int, date: Carbon}> $done مقاطع الحفظ المنجزة */
        $done = [];

        $this->recordHistory($student, array_slice($plan, 0, count($plan) - $inSessions), $done);
        $this->recordLessons($student, $lessons, array_slice($plan, count($plan) - $inSessions), $done);

        $this->recordJuzProgress($student, $done);
        $this->recordCurriculumProgress($student, self::ABILITY[$stage]);
    }

    /**
     * من بلغ مرحلةً متقدّمة لم يُسجَّل أمس: يُقدَّم تاريخ تسجيله إن كان أحدث مما تحتمله مرحلته.
     */
    private function ensureRegisteredEarlyEnough(Student $student, string $stage): void
    {
        $latest = $this->courseStart->copy()->subDays(self::MIN_REGISTERED_DAYS[$stage]);

        if (Carbon::parse($student->registration_date)->lte($latest)) {
            return;
        }

        $student->update(['registration_date' => $latest->subDays(fake()->numberBetween(0, 120))->toDateString()]);
    }

    /**
     * أي الحصص فيها تسميع ومن أي نوع: ثلاثةُ أخماس الحاضرين يسمّعون — حصّةٌ يسمّع فيها
     * الجميع تجعل «لا تسميعَ اليوم» حالةً لا تُرى قطّ. والتسميع حفظٌ جديد في الغالب،
     * ومراجعةٌ لما سبق، وتلاوةٌ أحياناً.
     *
     * @param  Collection<int, Attendance>  $attendances
     * @return array<int, array{attendance: Attendance, type: MemorizationType|null}>
     */
    private function planLessons(Collection $attendances): array
    {
        return $attendances->map(function (Attendance $attendance): array {
            if (! fake()->boolean(60)) {
                return ['attendance' => $attendance, 'type' => null];
            }

            $roll = fake()->numberBetween(1, 100);

            return ['attendance' => $attendance, 'type' => match (true) {
                $roll <= 65 => MemorizationType::Hifz,
                $roll <= 95 => MemorizationType::Murajaa,
                default => MemorizationType::Tilawah,
            }];
        })->all();
    }

    /**
     * ما حفظه الطالب قبل حصص الأسبوعين: مقاطع متتابعة موزَّعة بين تسجيله وبدء الدورة، تتخلّلها
     * مراجعاتٌ لما مضى. لا حصةَ ولا حلقةَ لها — تخصّ دوراتٍ سابقة.
     *
     * @param  array<int, array{surah: int, from: int, to: int}>  $chunks
     * @param  array<int, array{surah: int, from: int, to: int, date: Carbon}>  $done
     */
    private function recordHistory(Student $student, array $chunks, array &$done): void
    {
        $count = count($chunks);

        if ($count === 0) {
            return;
        }

        $start = Carbon::parse($student->registration_date);
        $days = max(1, (int) $start->diffInDays($this->courseStart, true) - 1);

        foreach ($chunks as $i => $chunk) {
            $date = $start->copy()->addDays((int) floor($days * $i / $count));

            $this->recite($student, $chunk, $date, MemorizationType::Hifz);
            $done[] = [...$chunk, 'date' => $date];

            if (count($done) > 2 && fake()->boolean(30)) {
                $this->recite($student, fake()->randomElement($done), $date, MemorizationType::Murajaa);
            }
        }
    }

    /**
     * تسميعُ حصص الأسبوعين الأخيرين: الحفظ الجديد يأخذ مقاطع [$upcoming] بترتيبها، وما عداه
     * مراجعةٌ أو تلاوةٌ لما حُفظ. ونقاط الأستاذ التقديرية مستقلّةٌ عن التسميع.
     *
     * @param  array<int, array{attendance: Attendance, type: MemorizationType|null}>  $lessons
     * @param  array<int, array{surah: int, from: int, to: int}>  $upcoming
     * @param  array<int, array{surah: int, from: int, to: int, date: Carbon}>  $done
     */
    private function recordLessons(Student $student, array $lessons, array $upcoming, array &$done): void
    {
        foreach ($lessons as ['attendance' => $attendance, 'type' => $type]) {
            $session = $attendance->attendanceSession;
            $date = Carbon::parse($session->session_date);
            $teacher = $this->teachers->get($session->course_circle_id);

            if ($type !== null) {
                $note = fake()->boolean(25) ? fake()->randomElement(self::RECITATION_NOTES) : null;
                $chunk = $type === MemorizationType::Hifz ? array_shift($upcoming) : null;

                if ($chunk !== null) {
                    $this->recite($student, $chunk, $date, MemorizationType::Hifz, $session, $teacher, $note);
                    $done[] = [...$chunk, 'date' => $date];
                } elseif ($done !== []) {
                    // لا مراجعةَ بلا محفوظ؛ وحفظٌ لم يبقَ له مقطعٌ يصير مراجعة.
                    $review = $type === MemorizationType::Hifz ? MemorizationType::Murajaa : $type;

                    $this->recite($student, fake()->randomElement($done), $date, $review, $session, $teacher, $note);
                }
            }

            if (fake()->boolean(20)) {
                $this->awardPoints($student, $session, $date, $teacher);
            }
        }
    }

    /**
     * سجلُّ تسميعٍ واحد. الأسطر الجديدة للحفظ وحده: المراجعة والتلاوة تعيدان ما حُفظ،
     * فلا أسطر جديدة لهما ولا نقاط — كما تحسب `SaveRecitation` على الخادم.
     *
     * @param  array{surah: int, from: int, to: int}  $chunk
     */
    private function recite(
        Student $student,
        array $chunk,
        Carbon $date,
        MemorizationType $type,
        ?AttendanceSession $session = null,
        ?Teacher $teacher = null,
        ?string $note = null,
    ): void {
        $grade = fake()->randomElement([
            RecitationGrade::Excellent, RecitationGrade::Excellent, RecitationGrade::Excellent, RecitationGrade::Excellent,
            RecitationGrade::VeryGood, RecitationGrade::VeryGood, RecitationGrade::VeryGood,
            RecitationGrade::Good, RecitationGrade::Good,
        ]);

        $lines = Quran::linesForRange($chunk['surah'], $chunk['from'], $chunk['surah'], $chunk['to']);
        $newLines = $type === MemorizationType::Hifz ? $lines : 0.0;

        MemorizationLog::create([
            'student_id' => $student->id,
            'course_circle_id' => $session?->course_circle_id,
            'attendance_session_id' => $session?->id,
            'date' => $date->toDateString(),
            'type' => $type,
            'grade' => $grade,
            'from_surah' => $chunk['surah'],
            'from_ayah' => $chunk['from'],
            'to_surah' => $chunk['surah'],
            'to_ayah' => $chunk['to'],
            'juz' => RecitationWalker::juzOf($chunk['surah'], $chunk['from']),
            'lines' => $lines,
            'new_lines' => $newLines,
            'points' => $this->settings->quranPoints($newLines, $grade),
            'teacher_id' => $teacher?->id,
            'notes' => $note,
        ]);
    }

    /**
     * نقطة تقديرية من الأستاذ: أغلبها مكافآت، وقلّةٌ خصمٌ للسلوك — فالنقاط تقبل السالب.
     */
    private function awardPoints(Student $student, AttendanceSession $session, Carbon $date, ?Teacher $teacher): void
    {
        $deduction = fake()->boolean(10);

        StudentPoint::create([
            'student_id' => $student->id,
            'course_circle_id' => $session->course_circle_id,
            'attendance_session_id' => $session->id,
            'points' => $deduction ? -fake()->numberBetween(1, 3) : fake()->numberBetween(1, 5),
            'reason' => $deduction
                ? PointReason::Behavior
                : fake()->randomElement([PointReason::Participation, PointReason::Excellence, PointReason::Reward, PointReason::Behavior]),
            'note' => $deduction ? 'كثرة الكلام أثناء الحلقة.' : null,
            'awarded_by' => $teacher?->user_id ?? $this->admin->id,
            'awarded_on' => $date->toDateString(),
        ]);
    }

    /**
     * أجزاء القرآن من حفظ الطالب نفسه، بالآيات لا بالسور (البقرة تمتدّ على ثلاثة أجزاء):
     * جزءٌ كلُّ آياته مسمَّعة «محفوظ»، وما بدأ «قيد الحفظ» بنسبة آياته — فيتّفق ما في شاشة
     * المناهج مع خريطة المصحف.
     *
     * @param  array<int, array{surah: int, from: int, to: int, date: Carbon}>  $done
     */
    private function recordJuzProgress(Student $student, array $done): void
    {
        if ($done === [] || $this->juzItems->isEmpty()) {
            return;
        }

        /** @var array<int, int> $covered آيات كل جزء المسمَّعة */
        $covered = [];
        /** @var array<int, array<int, Carbon>> $dates تواريخ المقاطع التي مرّت بكل جزء */
        $dates = [];

        foreach ($done as $chunk) {
            for ($ayah = $chunk['from']; $ayah <= $chunk['to']; $ayah++) {
                $juz = RecitationWalker::juzOf($chunk['surah'], $ayah);

                $covered[$juz] = ($covered[$juz] ?? 0) + 1;
                $dates[$juz][] = $chunk['date'];
            }
        }

        $totals = RecitationWalker::ayahsPerJuz();

        foreach ($this->juzItems as $juz => $item) {
            $count = $covered[$juz] ?? 0;

            if ($count === 0) {
                continue;
            }

            $juzDates = collect($dates[$juz]);
            $complete = $count >= $totals[$juz];

            $this->saveProgress(
                $student,
                $item,
                $complete ? ProgressStatus::Memorized : ProgressStatus::InProgress,
                (int) floor($count / $totals[$juz] * 100),
                $complete ? fake()->numberBetween(75, 100) : null,
                $juzDates->min(),
                $complete ? $juzDates->max() : null,
                $juzDates->max(),
            );
        }
    }

    /**
     * الأربعون النبوية والمتون: يتقدّم الطالب في البنود بالترتيب، فما قبل الأخير مُنجَز
     * وآخرُها غالباً قيد الحفظ. وكلما تقدّم الطالب في مراحل القرآن اتّسع ما أنجزه منها.
     */
    private function recordCurriculumProgress(Student $student, float $ability): void
    {

        foreach ([CurriculumType::Hadith, CurriculumType::Mutun] as $type) {
            $items = $this->items[$type->value] ?? new Collection;
            $touched = fake()->numberBetween(0, (int) round($items->count() * $ability * 0.8) + (fake()->boolean(15) ? 1 : 0));

            foreach ($items->take($touched)->values() as $index => $item) {
                $isLast = $index === $touched - 1;

                if ($isLast && fake()->boolean(55)) {
                    $started = Carbon::today()->subDays(fake()->numberBetween(5, 40));
                    $percent = fake()->numberBetween(10, 90);

                    $this->saveProgress($student, $item, ProgressStatus::InProgress, $percent, null, $started, null, Carbon::today()->subDays(fake()->numberBetween(0, 10)));

                    continue;
                }

                $completed = Carbon::today()->subDays(($touched - $index) * fake()->numberBetween(8, 20));

                $this->saveProgress(
                    $student,
                    $item,
                    fake()->boolean(25) ? ProgressStatus::Mastered : ProgressStatus::Memorized,
                    100,
                    fake()->numberBetween(70, 100),
                    $completed->copy()->subDays(fake()->numberBetween(10, 30)),
                    $completed,
                    $completed,
                );
            }
        }
    }

    /**
     * يمرّ بإجراء الحفظ الحقيقي فتُحسب النقاط بإعدادات المعهد، ثم تُصحَّح تواريخه:
     * الإجراء يؤرّخ كل شيء باليوم، والبذرة تحتاج إنجازاتٍ متفرّقة في الزمن.
     */
    private function saveProgress(
        Student $student,
        CurriculumItem $item,
        ProgressStatus $status,
        int $percent,
        ?int $score,
        ?Carbon $startedOn,
        ?Carbon $completedOn,
        Carbon $achievedOn,
    ): void {
        $progress = app(SaveStudentCurriculumProgress::class)->handle($student, $item, [
            'status' => $status->value,
            'percent' => $percent,
            'score' => $score,
            'notes' => fake()->boolean(20) ? fake()->randomElement(self::PROGRESS_NOTES) : null,
        ]);

        $progress->update([
            'started_on' => $startedOn?->toDateString(),
            'completed_on' => $completedOn?->toDateString(),
            'achieved_on' => $achievedOn->toDateString(),
            'teacher_id' => $this->teachers->get($progress->course_circle_id)?->id,
        ]);
    }

    /**
     * @return Collection<int, Teacher> أستاذ كل حلقة الأساسي، بمفتاح course_circle_id
     */
    private function mainTeachers(Course $course): Collection
    {
        return CourseCircleTeacher::query()
            ->where('role', TeacherRole::Main)
            ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $course->id))
            ->with('teacher')
            ->get()
            ->mapWithKeys(fn (CourseCircleTeacher $row) => [$row->course_circle_id => $row->teacher]);
    }

    /**
     * بنود المناهج العامة. تبقى فارغةً إن لم يُشغَّل `CurriculumSeeder` — فلا يتعطّل البذر
     * وإنما يُترك تقدّم المناهج، ويبقى التسميع.
     */
    private function loadCurricula(): void
    {
        $items = fn (CurriculumType $type): Collection => CurriculumItem::query()
            ->whereHas('curriculum', fn ($query) => $query->whereNull('institute_id')->where('type', $type))
            ->orderBy('sort_order')
            ->get();

        $this->juzItems = $items(CurriculumType::Quran)
            ->filter(fn (CurriculumItem $item) => isset($item->meta['juz']))
            ->keyBy(fn (CurriculumItem $item) => (int) $item->meta['juz']);

        $this->items = [
            CurriculumType::Hadith->value => $items(CurriculumType::Hadith),
            CurriculumType::Mutun->value => $items(CurriculumType::Mutun),
        ];
    }
}
