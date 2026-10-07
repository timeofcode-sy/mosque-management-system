<?php

namespace Database\Seeders;

use App\Actions\RecalculateCircleStats;
use App\Enums\AttendanceStatus;
use App\Enums\CourseStatus;
use App\Enums\GuardianRelation;
use App\Enums\MemorizationType;
use App\Enums\PointReason;
use App\Enums\RecitationGrade;
use App\Enums\SessionStatus;
use App\Enums\TeacherRole;
use App\Models\Announcement;
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
use App\Models\MemorizationLog;
use App\Models\PersonalTrait;
use App\Models\Shift;
use App\Models\ShiftDay;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\StudentTrait;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\App;
use Spatie\Permission\PermissionRegistrar;

/**
 * معهد تجريبي كامل: دورة جارية، دوامان، ست حلقات، ثمانون طالباً بأولياء أمورهم،
 * وتفقّد لآخر أسبوعين — يكفي لتجربة اللوحة والتقارير والمزامنة.
 */
class DemoInstituteSeeder extends Seeder
{
    /**
     * @var array<int, string>
     */
    private const CIRCLE_NAMES = [
        'أبي بن كعب', 'زيد بن ثابت', 'عبد الله بن مسعود',
        'أبي موسى الأشعري', 'معاذ بن جبل', 'عثمان بن عفان',
    ];

    private const STUDENTS_PER_CIRCLE = 13;

    public function run(): void
    {
        $institute = Institute::factory()->create([
            'name' => 'معهد النور لتحفيظ القرآن الكريم',
            'short_name' => 'معهد النور',
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

            CourseCircleTeacher::create([
                'course_circle_id' => $courseCircle->id,
                'teacher_id' => Teacher::factory()->create(['institute_id' => $institute->id])->id,
                'role' => TeacherRole::Main,
                'joined_on' => $course->starts_on,
            ]);

            $this->enrollStudents($institute, $courseCircle, $personalTraits);

            $courseCircles->push($courseCircle);
        }

        $this->recordAttendance($courseCircles, $admin);
        $this->seedAnnouncements($institute, $admin);

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
        for ($i = 0; $i < self::STUDENTS_PER_CIRCLE; $i++) {
            $student = Student::factory()->create(['institute_id' => $institute->id]);

            $father = Guardian::factory()->create([
                'institute_id' => $institute->id,
                'full_name' => "{$student->father_name} {$student->family_name}",
            ]);

            $mother = Guardian::factory()->mother()->create(['institute_id' => $institute->id]);

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
                'enrolled_on' => $courseCircle->course->starts_on,
            ]);
        }
    }

    /**
     * @param  Collection<int, CourseCircle>  $courseCircles
     */
    private function recordAttendance(Collection $courseCircles, User $admin): void
    {
        foreach ($courseCircles as $courseCircle) {
            $weekdays = $courseCircle->shift->days->pluck('weekday')->all();
            $enrollments = $courseCircle->enrollments()->get();

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

                foreach ($enrollments as $enrollment) {
                    $attendance = Attendance::factory()->create([
                        'attendance_session_id' => $session->id,
                        'student_id' => $enrollment->student_id,
                        'enrollment_id' => $enrollment->id,
                        'status' => fake()->randomElement([
                            AttendanceStatus::Present, AttendanceStatus::Present,
                            AttendanceStatus::Present, AttendanceStatus::Present,
                            AttendanceStatus::Present, AttendanceStatus::Present,
                            AttendanceStatus::Late, AttendanceStatus::Absent, AttendanceStatus::Excused,
                        ]),
                        'recorded_by' => $admin->id,
                        'recorded_at' => $date->copy()->setTime(9, 0),
                    ]);

                    $this->recordLesson($session, $enrollment, $attendance, $date, $admin);
                }
            }
        }
    }

    /**
     * تسميعُ الحاضر ونقاطُه — ✅ م.8.1.
     *
     * 🔴 **وكان حاجباً موثَّقاً منذ م.4.5**: البذرةُ تنتج حضوراً وحده، فـ
     * `migrate:fresh --seed` يعطي معهداً بلا تسميعةٍ ولا نقطة — ويبدو تطبيقُ
     * الطالب **شاشةَ حضورٍ فقط** ([APPS-FEATURES.md §6.4](../../docs/APPS-FEATURES.md)
     * البند 2). وهو صنفُ نقصٍ لا يُكتشف باختبار: الاختبارُ ينشئ ما يحتاجه، ولا
     * يشكو أحدٌ إلا من يفتح التطبيقَ على قاعدةٍ مبذورة.
     *
     * **والغائبُ لا يُسمّع**: القاعدةُ نفسُها التي تحكم الإحصاءَ كلَّه — ما لم
     * يُسجَّل لا يُفترض. وبذرةٌ تعطي تسميعاً لطالبٍ غائب تصنع بياناً لا يقع في
     * الواقع، فتُخفي عطباً يقع.
     */
    private function recordLesson(
        AttendanceSession $session,
        Enrollment $enrollment,
        Attendance $attendance,
        Carbon $date,
        User $admin,
    ): void {
        if (! in_array($attendance->status, [AttendanceStatus::Present, AttendanceStatus::Late], true)) {
            return;
        }

        // ثلاثةُ أخماسِ الحاضرين يسمّعون: حصّةٌ لا يسمّع فيها الجميعُ هي الواقع،
        // وبذرةٌ يسمّع فيها الكلُّ تجعل «لا تسميعَ اليوم» حالةً لا تُرى قطّ.
        if (fake()->boolean(60)) {
            $lines = fake()->numberBetween(3, 20);

            MemorizationLog::create([
                'student_id' => $enrollment->student_id,
                'course_circle_id' => $session->course_circle_id,
                'attendance_session_id' => $session->id,
                'date' => $date->toDateString(),
                'type' => fake()->randomElement(MemorizationType::cases()),
                'grade' => fake()->randomElement(RecitationGrade::cases()),
                'lines' => $lines,
                'new_lines' => $lines,
                // النقاطُ **مجمَّدةٌ في الصفّ** كما يفعل `StudentPoints` على
                // الخادم — والعميلُ يقرؤها ولا يعيد حسابها.
                'points' => round($lines / 15 * 10, 2),
                'teacher_id' => null,
            ]);
        }

        if (fake()->boolean(20)) {
            StudentPoint::create([
                'student_id' => $enrollment->student_id,
                'course_circle_id' => $session->course_circle_id,
                'attendance_session_id' => $session->id,
                'points' => fake()->numberBetween(1, 5),
                'reason' => fake()->randomElement(PointReason::cases()),
                'awarded_by' => $admin->id,
                'awarded_on' => $date->toDateString(),
            ]);
        }
    }

    /**
     * إعلانان — ✅ م.8.1، فشاشةُ الطالب لا تُفتح فارغة.
     */
    private function seedAnnouncements(Institute $institute, User $admin): void
    {
        Announcement::create([
            'institute_id' => $institute->id,
            'title' => 'انتظام الدوام',
            'body' => 'نذكّر الطلابَ بالحضور قبل بداية الحصّة بعشر دقائق، وجزاكم الله خيراً.',
            'scope' => 'all',
            'created_by' => $admin->id,
            'published_at' => now()->subDays(3),
        ]);

        Announcement::create([
            'institute_id' => $institute->id,
            'title' => 'مسابقة حفظ جزء عمّ',
            'body' => 'تُقام المسابقةُ نهايةَ الشهر، والتسجيلُ عند أستاذ الحلقة.',
            'scope' => 'all',
            'created_by' => $admin->id,
            'published_at' => now()->subDay(),
        ]);
    }
}
