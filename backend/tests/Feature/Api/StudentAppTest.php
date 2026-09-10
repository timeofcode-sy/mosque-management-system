<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Models\Announcement;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * عقدُ سطح الطالب — م.8.1.
 *
 * 🔑 وأهمُّ ما يحرسه: **ألّا يصل جهازَ الطالب صفٌّ عن زميل**. الرتبةُ تُحسب في
 * الخادم ويعود منها الرقمُ وحده ([PHASE-8-STAGES.MD §1.1](../../../../docs/PHASE-8-STAGES.MD)).
 */
class StudentAppTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->student = $this->actingAsStudent();
    }

    // ── الرتبة ────────────────────────────────────────────────────────────────

    /**
     * 🔑 **الاختبارُ الذي يحرس القرار**: الرتبةُ تصل رقماً، ولا يصل معها اسمُ
     * زميلٍ ولا نسبتُه ولا معرّفُه.
     */
    public function test_the_standing_is_a_number_and_carries_nothing_about_peers(): void
    {
        $circle = $this->makeCourseCircle();
        $me = $this->enrol($this->student, $circle);
        // الاسمُ من أعمدته الثلاثة — `full_name` صفةٌ محسوبة لا عمود.
        $rival = Student::factory()->create([
            'institute_id' => $this->institute->id,
            'first_name' => 'زميلٌ',
            'father_name' => 'متفوّق',
            'family_name' => 'جداً',
        ]);
        $this->enrol($rival, $circle);

        $session = $this->completedSession($circle);
        $this->attend($session, $this->student, AttendanceStatus::Absent);
        $this->attend($session, $rival, AttendanceStatus::Present);

        $response = $this->getJson('/api/v1/student/me/standing')->assertOk();

        $response->assertJsonPath('data.rank', 2);
        $response->assertJsonPath('data.peers', 2);
        // assertEquals لا assertSame: `json_encode(0.0) === '0'` — القاعدةُ
        // الموثَّقة في [API.md §3.4].
        $this->assertEquals(0.0, $response->json('data.rate'));

        // ولا أثرَ للزميل في الحمولة كلِّها.
        $raw = $response->getContent();
        $this->assertStringNotContainsString('زميلٌ', $raw);
        $this->assertStringNotContainsString($rival->uuid, $raw);

        unset($me);
    }

    /**
     * التعادلُ يأخذ الرتبةَ نفسَها — كما في تقرير نقاط الحلقة منذ م.4.5، فلا
     * يفترق الرقمان.
     */
    public function test_a_tie_shares_the_same_rank(): void
    {
        $circle = $this->makeCourseCircle();
        $this->enrol($this->student, $circle);
        $peer = Student::factory()->create(['institute_id' => $this->institute->id]);
        $this->enrol($peer, $circle);

        $session = $this->completedSession($circle);
        $this->attend($session, $this->student, AttendanceStatus::Present);
        $this->attend($session, $peer, AttendanceStatus::Present);

        $this->getJson('/api/v1/student/me/standing')
            ->assertOk()
            ->assertJsonPath('data.rank', 1)
            ->assertJsonPath('data.peers', 2);
    }

    /**
     * 🔑 قاعدةُ م.6.6: `null` تعني «لم يُقَس» لا «الأخير».
     */
    public function test_a_student_with_no_attendance_yet_is_unranked_not_last(): void
    {
        $circle = $this->makeCourseCircle();
        $this->enrol($this->student, $circle);

        $this->getJson('/api/v1/student/me/standing')
            ->assertOk()
            ->assertJsonPath('data.rank', null)
            ->assertJsonPath('data.rate', null);
    }

    public function test_a_student_with_no_active_enrolment_is_unranked_not_an_error(): void
    {
        $this->getJson('/api/v1/student/me/standing')
            ->assertOk()
            ->assertJsonPath('data.rank', null)
            ->assertJsonPath('data.circle_name', null)
            ->assertJsonPath('data.peers', 0);
    }

    // ── النقاط ────────────────────────────────────────────────────────────────

    public function test_the_points_arrive_broken_down_by_source(): void
    {
        $circle = $this->makeCourseCircle();
        $this->enrol($this->student, $circle);

        StudentPoint::factory()->create([
            'student_id' => $this->student->id,
            'course_circle_id' => $circle->id,
            'points' => 5,
            'awarded_on' => now()->toDateString(),
        ]);

        $this->getJson('/api/v1/student/me/points')
            ->assertOk()
            ->assertJsonStructure(['data' => ['attendance', 'manual', 'total']]);
    }

    /**
     * معهدٌ بين دورتين حالٌ عادية — أصفارٌ لا رسالةُ عطب.
     */
    public function test_no_current_course_gives_zeros_not_an_error(): void
    {
        $this->course->forceFill(['is_current' => false])->save();

        $this->getJson('/api/v1/student/me/points')
            ->assertOk()
            ->assertJsonPath('data.total', 0);
    }

    // ── الإعلانات ─────────────────────────────────────────────────────────────

    public function test_a_student_reads_the_institute_wide_announcements(): void
    {
        $this->publish(['scope' => 'all', 'title' => 'بداية الدورة']);

        $this->getJson('/api/v1/student/me/announcements')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.title', 'بداية الدورة');
    }

    /**
     * 🔑 **الترشيحُ في الخادم**: إعلانُ حلقةٍ ليست له لا يصل جهازَه أصلاً.
     */
    public function test_an_announcement_aimed_at_another_circle_never_arrives(): void
    {
        $mine = $this->makeCourseCircle();
        $theirs = $this->makeCourseCircle();
        $this->enrol($this->student, $mine);

        $this->publish(['scope' => 'circle', 'scope_ids' => [$mine->id], 'title' => 'حلقتي']);
        $this->publish(['scope' => 'circle', 'scope_ids' => [$theirs->id], 'title' => 'حلقةٌ أخرى']);

        $titles = collect($this->getJson('/api/v1/student/me/announcements')->assertOk()->json('data'))
            ->pluck('title')->all();

        $this->assertSame(['حلقتي'], $titles);
    }

    /**
     * المسودّةُ ليست إعلاناً، والمجدوَلُ لم يحن وقتُه.
     */
    public function test_unpublished_and_future_announcements_are_not_read(): void
    {
        $this->publish(['scope' => 'all', 'title' => 'مسودّة', 'published_at' => null]);
        $this->publish(['scope' => 'all', 'title' => 'لاحقاً', 'published_at' => now()->addWeek()]);

        $this->getJson('/api/v1/student/me/announcements')->assertOk()->assertJsonCount(0, 'data');
    }

    /**
     * ولا `scope_ids` في الخرج — معرّفاتُ الحلقات الأخرى ليست من شأن قارئه.
     */
    public function test_the_payload_never_leaks_the_scope_ids(): void
    {
        $circle = $this->makeCourseCircle();
        $this->enrol($this->student, $circle);
        $this->publish(['scope' => 'circle', 'scope_ids' => [$circle->id], 'title' => 'إعلان']);

        $row = $this->getJson('/api/v1/student/me/announcements')->assertOk()->json('data.0');

        $this->assertArrayNotHasKey('scope_ids', $row);
        $this->assertSame('circle', $row['scope']);
    }

    // ── النطاق ────────────────────────────────────────────────────────────────

    /**
     * لا مُعرِّفَ في أي مسار — النطاقُ من الحساب لا من الطلب.
     */
    public function test_every_student_route_is_scoped_by_the_account(): void
    {
        $user = User::factory()->create();
        $this->assignRole($user, 'teacher');
        Sanctum::actingAs($user, ['*']);

        foreach (['standing', 'points', 'announcements'] as $path) {
            $this->getJson("/api/v1/student/me/$path")->assertForbidden();
        }
    }

    // ── مساعِدات ──────────────────────────────────────────────────────────────

    private function actingAsStudent(): Student
    {
        $user = User::factory()->create();
        $student = Student::factory()->create([
            'institute_id' => $this->institute->id,
            'user_id' => $user->id,
        ]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('student');
        Sanctum::actingAs($user, ['*']);

        return $student;
    }

    private function enrol(Student $student, CourseCircle $circle): Enrollment
    {
        return Enrollment::factory()->create([
            'course_circle_id' => $circle->id,
            'student_id' => $student->id,
            'enrolled_on' => now()->subMonth()->toDateString(),
            'left_on' => null,
        ]);
    }

    private function completedSession(CourseCircle $circle): AttendanceSession
    {
        return AttendanceSession::factory()->completed()->create(['course_circle_id' => $circle->id]);
    }

    private function attend(AttendanceSession $session, Student $student, AttendanceStatus $status): void
    {
        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => $status,
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function publish(array $attributes): Announcement
    {
        return Announcement::create([
            'institute_id' => $this->institute->id,
            'body' => 'نصُّ الإعلان.',
            'published_at' => now()->subHour(),
            ...$attributes,
        ]);
    }
}
