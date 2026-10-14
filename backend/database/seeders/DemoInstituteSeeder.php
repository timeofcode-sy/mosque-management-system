<?php

namespace Database\Seeders;

use App\Actions\RecalculateCircleStats;
use App\Actions\TransferStudent;
use App\Enums\AttendanceStatus;
use App\Enums\CourseStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\ExcuseStatus;
use App\Enums\GuardianRelation;
use App\Enums\NotePolarity;
use App\Enums\SessionStatus;
use App\Enums\TeacherRole;
use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Shift;
use App\Models\ShiftDay;
use App\Models\Student;
use App\Models\StudentTrait;
use App\Models\Teacher;
use App\Models\TeacherAttendance;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\App;
use Spatie\Permission\PermissionRegistrar;

/**
 * معهد عمر الفاروق التجريبي: دورة جارية، دوامان، ست حلقات، ثمانون طالباً بأولياء أمورهم،
 * وتفقّد لآخر أسبوعين بحضور الأساتذة وأعذار الغياب وانتقالات الطلاب بين الحلقات.
 * ثم يستدعي بذرتي المحفوظات (`DemoMemorizationSeeder`) وما يحيط بالطالب
 * (`DemoExtrasSeeder`) — يكفي كلُّه لتجربة اللوحة والتقارير والمزامنة والتطبيقات الثلاثة.
 */
class DemoInstituteSeeder extends Seeder
{
    private const INSTITUTE_NAME = 'معهد عمر الفاروق';

    /**
     * @var array<int, string>
     */
    private const CIRCLE_NAMES = [
        'أبي بن كعب', 'زيد بن ثابت', 'عبد الله بن مسعود',
        'أبي موسى الأشعري', 'معاذ بن جبل', 'عثمان بن عفان',
    ];

    /**
     * مناطق من البلدة لعنوان الطالب الدائم — المعهد في عربين فأغلب طلابه من حولها.
     *
     * @var array<int, string>
     */
    private const QUARTERS = ['الحي الشرقي', 'الحي الغربي', 'الحي الشمالي', 'الحي الجنوبي', 'وسط البلد'];

    /**
     * @var array<int, string>
     */
    private const EXCUSE_REASONS = ['مرض', 'موعد طبي', 'سفر مع العائلة', 'ظرف عائلي', 'امتحانات المدرسة'];

    /**
     * ملاحظات الأستاذ على سلوك الحاضر: إيجابية وسلبية، وهي ما يبني مقياس «الأدب» في الإحصائيات.
     *
     * @var array<string, array<int, string>>
     */
    private const BEHAVIOUR_NOTES = [
        'positive' => ['مشاركة فعّالة في الحلقة.', 'ساعد زملاءه في المراجعة.', 'حسن الأدب مع الأستاذ.', 'التزم بالهدوء طوال الحصة.'],
        'negative' => ['كثر الكلام أثناء التسميع.', 'نسي مصحفه.', 'تأخر في الاستعداد للحصة.', 'شغل زملاءه عن الحفظ.'],
    ];

    private const STUDENTS_PER_CIRCLE = 13;

    /** @var array<int, Teacher> الأستاذ الأساسي لكل حلقة، بمفتاح course_circle_id */
    private array $mainTeachers = [];

    /** @var array<int, int|null> حساب ولي الأمر الأساسي لكل طالب، بمفتاح student_id */
    private array $guardianUsers = [];

    /**
     * البذرُ يُنشئ حسابات بأسماء مستخدمين ثابتة (admin1000 …)، فتشغيلُه على قاعدةٍ مبذورةٍ يسقط بخرق
     * UNIQUE بعد أن يكون قد كتب نصفَ المعهد. وهو أمرٌ يقع كثيراً: `migrate --seed` مرّتين، أو على قاعدة
     * التجربة القديمة. فيُترك المعهدُ التجريبي كما هو، ومن أراد قاعدةً نظيفة شغّل `migrate:fresh --seed`.
     */
    public function run(): void
    {
        if (User::where('username', 'admin1000')->exists()) {
            $this->command?->warn('المعهد التجريبي مبذور من قبل — لا شيء يُضاف. لقاعدة نظيفة: php artisan migrate:fresh --seed');

            return;
        }

        $institute = Institute::factory()->create([
            'name' => self::INSTITUTE_NAME,
            'short_name' => self::INSTITUTE_NAME,
            'phone' => '+963935650325',
            'email' => null,
            'address' => 'ريف دمشق - عربين',
        ]);

        /** إسناد الأدوار في Spatie مرتبط بمعهد (teams) عبر المفتاح institute_id */
        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);

        $admin = User::factory()->create([
            'username' => 'admin1000',
            'first_name' => 'مشرف',
            'last_name' => 'المعهد',
            'email' => 'admin@mousqe.test',
        ]);
        $admin->assignRole('admin');

        $this->seedGlobalAccounts();

        $course = Course::factory()->current()->create([
            'institute_id' => $institute->id,
            'name' => 'دورة '.Carbon::today()->year,
            'starts_on' => Carbon::today()->subMonth()->startOfMonth(),
            'ends_on' => Carbon::today()->addMonths(2)->endOfMonth(),
            'status' => CourseStatus::Active,
        ]);

        $morning = Shift::factory()->create(['course_id' => $course->id]);
        $evening = Shift::factory()->evening()->create(['course_id' => $course->id]);

        /** الأحد والثلاثاء والخميس صباحاً، والاثنين والأربعاء مساءً */
        foreach ([0, 2, 4] as $weekday) {
            ShiftDay::factory()->create(['shift_id' => $morning->id, 'weekday' => $weekday]);
        }

        foreach ([1, 3] as $weekday) {
            ShiftDay::factory()->create(['shift_id' => $evening->id, 'weekday' => $weekday]);
        }

        $personalTraits = PersonalTrait::query()->whereNull('institute_id')->get();
        $courseCircles = new Collection;

        foreach (self::CIRCLE_NAMES as $index => $circleName) {
            $circle = Circle::factory()->create([
                'institute_id' => $institute->id,
                'name' => "حلقة {$circleName}",
                'sort_order' => $index,
            ]);

            $courseCircle = CourseCircle::factory()->create([
                'course_id' => $course->id,
                'circle_id' => $circle->id,
                'shift_id' => $index < 3 ? $morning->id : $evening->id,
                'room' => 'القاعة '.($index + 1),
            ]);

            $teacher = Teacher::factory()->create(['institute_id' => $institute->id]);

            CourseCircleTeacher::create([
                'course_circle_id' => $courseCircle->id,
                'teacher_id' => $teacher->id,
                'role' => TeacherRole::Main,
                'joined_on' => $course->starts_on,
            ]);

            $this->mainTeachers[$courseCircle->id] = $teacher;

            $this->enrollStudents($institute, $courseCircle, $personalTraits);

            $courseCircles->push($courseCircle);
        }

        // الانتقالات قبل التفقّد: الطالب المنقول يُتفقَّد في حلقته الجديدة فقط.
        $this->transferStudents($courseCircles, $admin);
        $this->recordAttendance($courseCircles, $admin);
        $this->seedExcuses($admin);

        // بعد الحضور لا قبله: لا تسميع لغائب، والوسوم تُشتقّ من الحفظ والحضور المبذورَين.
        $this->callWith(DemoMemorizationSeeder::class, ['institute' => $institute, 'admin' => $admin]);
        $this->callWith(DemoExtrasSeeder::class, ['institute' => $institute, 'admin' => $admin]);

        // الإحصاء يُحسب عادةً لحظة إغلاق كل جلسة؛ البذور تكتب الجلسات مباشرةً فتحتاج تشغيله مرّة.
        app(RecalculateCircleStats::class)->forCourse($course->id);
    }

    /**
     * حسابان عابران للمعاهد: الأدوار تُسنَد خارج كل معهد (User::GLOBAL_TEAM_ID)
     * لا داخل المعهد التجريبي — وإلا لصارا مديرَي معهدٍ واحد لا مشرفاً أعلى ومبرمجاً.
     */
    private function seedGlobalAccounts(): void
    {
        User::factory()->create([
            'username' => 'sadmin1000',
            'first_name' => 'المشرف',
            'last_name' => 'الأعلى',
            'email' => 'super@mousqe.test',
        ])->assignGlobalRole('super_admin');

        User::factory()->create([
            'username' => 'dev1000',
            'first_name' => 'مبرمج',
            'last_name' => 'النظام',
            'email' => 'dev@mousqe.test',
        ])->assignGlobalRole('developer');
    }

    /**
     * @param  Collection<int, PersonalTrait>  $personalTraits
     */
    private function enrollStudents(Institute $institute, CourseCircle $courseCircle, Collection $personalTraits): void
    {
        $courseStart = Carbon::parse($courseCircle->course->starts_on);

        for ($i = 0; $i < self::STUDENTS_PER_CIRCLE; $i++) {
            $student = Student::factory()->create([
                'institute_id' => $institute->id,
                // التسجيل في المعهد سابقٌ لبدء الدورة: الطالب يدخل الدورة وله محفوظٌ من قبلها.
                'registration_date' => $courseStart->copy()->subDays(fake()->numberBetween(14, 600)),
                'permanent_address' => 'ريف دمشق - عربين - '.fake()->randomElement(self::QUARTERS),
            ]);

            $father = Guardian::factory()->create([
                'institute_id' => $institute->id,
                'first_name' => $student->father_name,
                'family_name' => $student->family_name,
            ]);

            $mother = Guardian::factory()->mother()->create(['institute_id' => $institute->id]);

            $this->guardianUsers[$student->id] = $father->user_id;

            GuardianStudent::create([
                'guardian_id' => $father->id,
                'student_id' => $student->id,
                'relation' => GuardianRelation::Father,
                'is_primary' => true,
            ]);

            GuardianStudent::create([
                'guardian_id' => $mother->id,
                'student_id' => $student->id,
                'relation' => GuardianRelation::Mother,
            ]);

            foreach ($personalTraits->random(min(3, $personalTraits->count())) as $personalTrait) {
                StudentTrait::create([
                    'student_id' => $student->id,
                    'trait_id' => $personalTrait->id,
                ]);
            }

            Enrollment::factory()->create([
                'course_circle_id' => $courseCircle->id,
                'student_id' => $student->id,
                'enrolled_on' => $courseStart,
            ]);
        }
    }

    /**
     * ثلاثة انتقالات بين الدوامين قبل ثلاثة أسابيع، عبر إجراء النقل الحقيقي: يُغلق تسجيلُ
     * الطالب القديم «منقولاً» ويُفتح له تسجيلٌ جديد، فيظهر سجلّ النقل في ملفه.
     *
     * @param  Collection<int, CourseCircle>  $courseCircles
     */
    private function transferStudents(Collection $courseCircles, User $admin): void
    {
        $transfers = [
            [0, 4, 'ارتباطه بالمدرسة صباحاً فنُقل إلى الدوام المسائي.'],
            [3, 1, 'رغبة ولي الأمر في الدوام الصباحي.'],
            [2, 5, 'ملاءمة الحلقة الأخرى لمستواه في الحفظ.'],
        ];

        foreach ($transfers as [$from, $to, $reason]) {
            $enrollment = $courseCircles[$from]->enrollments()->where('status', EnrollmentStatus::Active)->inRandomOrder()->first();
            $student = $enrollment === null ? null : Student::find($enrollment->student_id);

            if ($student === null) {
                continue;
            }

            app(TransferStudent::class)->handle($student, $courseCircles[$to], $reason, $admin, Carbon::today()->subDays(21)->toDateString());
        }
    }

    /**
     * @param  Collection<int, CourseCircle>  $courseCircles
     */
    private function recordAttendance(Collection $courseCircles, User $admin): void
    {
        foreach ($courseCircles as $courseCircle) {
            $weekdays = $courseCircle->shift->days->pluck('weekday')->all();

            // الجارية وحدها: المنقول عن الحلقة لا يُتفقَّد فيها بعد انتقاله.
            $enrollments = $courseCircle->enrollments()->where('status', EnrollmentStatus::Active)->get();

            for ($daysAgo = 14; $daysAgo >= 1; $daysAgo--) {
                $date = Carbon::today()->subDays($daysAgo);

                if (! in_array($date->dayOfWeek, $weekdays, true)) {
                    continue;
                }

                $session = AttendanceSession::factory()->create([
                    'course_circle_id' => $courseCircle->id,
                    'session_date' => $date,
                    'status' => SessionStatus::Completed,
                    'completed_at' => $date->copy()->setTime(11, 0),
                    'opened_by' => $admin->id,
                    'taken_by' => $admin->id,
                ]);

                $this->recordTeacherAttendance($session, $this->mainTeachers[$courseCircle->id], $date, $admin);

                foreach ($enrollments as $enrollment) {
                    if (Carbon::parse($enrollment->enrolled_on)->gt($date)) {
                        continue;
                    }

                    $status = fake()->randomElement([
                        AttendanceStatus::Present, AttendanceStatus::Present,
                        AttendanceStatus::Present, AttendanceStatus::Present,
                        AttendanceStatus::Present, AttendanceStatus::Present,
                        AttendanceStatus::Late, AttendanceStatus::Absent, AttendanceStatus::Excused,
                    ]);

                    Attendance::factory()->create([
                        'attendance_session_id' => $session->id,
                        'student_id' => $enrollment->student_id,
                        'enrollment_id' => $enrollment->id,
                        'status' => $status,
                        'recorded_by' => $admin->id,
                        'recorded_at' => $date->copy()->setTime(9, 0),
                        ...$this->detailsFor($status),
                    ]);
                }
            }
        }
    }

    /**
     * ما يلحق بحالة الطالب: دقائق التأخر للمتأخر، وللحاضر ملاحظةٌ على سلوكه أحياناً.
     *
     * @return array<string, mixed>
     */
    private function detailsFor(AttendanceStatus $status): array
    {
        if ($status === AttendanceStatus::Late) {
            return ['late_minutes' => fake()->numberBetween(5, 30)];
        }

        if ($status !== AttendanceStatus::Present || ! fake()->boolean(12)) {
            return [];
        }

        $polarity = fake()->boolean(70) ? NotePolarity::Positive : NotePolarity::Negative;

        return [
            'note' => fake()->randomElement(self::BEHAVIOUR_NOTES[$polarity->value]),
            'note_polarity' => $polarity,
        ];
    }

    /**
     * حضور أستاذ الحلقة: يواظب غالباً، ويتأخر أو يستأذن نادراً.
     */
    private function recordTeacherAttendance(AttendanceSession $session, Teacher $teacher, Carbon $date, User $admin): void
    {
        $roll = fake()->numberBetween(1, 100);

        $status = match (true) {
            $roll <= 90 => AttendanceStatus::Present,
            $roll <= 97 => AttendanceStatus::Late,
            default => AttendanceStatus::Excused,
        };

        TeacherAttendance::create([
            'attendance_session_id' => $session->id,
            'teacher_id' => $teacher->id,
            'status' => $status,
            'late_minutes' => $status === AttendanceStatus::Late ? fake()->numberBetween(5, 20) : null,
            'note' => $status === AttendanceStatus::Excused ? 'ظرفٌ طارئ وأُنيب عنه أحد الأساتذة.' : null,
            'recorded_by' => $admin->id,
            'recorded_at' => $date->copy()->setTime(8, 45),
        ]);
    }

    /**
     * أعذار الغياب، متّسقةً مع التفقّد المبذور:
     * - كل «غائب بعذر» له عذرٌ **مقبول** يغطّي يومه، لأن قبول العذر هو ما يحوّل الغياب إلى إذن.
     * - ثلث «الغائبين» قدّم أولياؤهم عذراً لم يُقبل بعد، أو رُفض لعدم كفاية السبب.
     * - وثلاثة أعذار لأيامٍ قادمة تنتظر البتّ — ما يراه المشرف أول ما يفتح لوحته.
     */
    private function seedExcuses(User $admin): void
    {
        $attendances = Attendance::query()
            ->whereIn('status', [AttendanceStatus::Excused, AttendanceStatus::Absent])
            ->with('attendanceSession')
            ->get();

        foreach ($attendances as $attendance) {
            $date = Carbon::parse($attendance->attendanceSession->session_date);

            if ($attendance->status === AttendanceStatus::Excused) {
                $this->excuse($attendance->student_id, $date, $date, ExcuseStatus::Approved, $admin, $date->copy()->subDay()->setTime(18, 0));

                continue;
            }

            if (fake()->boolean(33)) {
                $rejected = fake()->boolean(60);

                $this->excuse(
                    $attendance->student_id,
                    $date,
                    $date,
                    $rejected ? ExcuseStatus::Rejected : ExcuseStatus::Pending,
                    $rejected ? $admin : null,
                    $rejected ? $date->copy()->addDay()->setTime(10, 0) : null,
                    $rejected ? 'لم يُرفق ما يثبت العذر.' : null,
                );
            }
        }

        $upcoming = Student::query()->inRandomOrder()->limit(3)->pluck('id');

        foreach ($upcoming as $studentId) {
            $from = Carbon::today()->addDays(fake()->numberBetween(1, 3));

            $this->excuse($studentId, $from, $from->copy()->addDays(fake()->numberBetween(0, 2)), ExcuseStatus::Pending);
        }
    }

    private function excuse(
        int $studentId,
        Carbon $from,
        Carbon $to,
        ExcuseStatus $status,
        ?User $reviewer = null,
        ?Carbon $reviewedAt = null,
        ?string $reviewNote = null,
    ): void {
        AbsenceExcuse::create([
            'student_id' => $studentId,
            'from_date' => $from->toDateString(),
            'to_date' => $to->toDateString(),
            'reason' => fake()->randomElement(self::EXCUSE_REASONS),
            'submitted_by' => $this->guardianUsers[$studentId] ?? null,
            'status' => $status,
            'reviewed_by' => $reviewer?->id,
            'reviewed_at' => $reviewedAt,
            'review_note' => $reviewNote,
        ]);
    }
}
