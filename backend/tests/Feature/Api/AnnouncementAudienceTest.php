<?php

namespace Tests\Feature\Api;

use App\Enums\GuardianRelation;
use App\Enums\TeacherRole;
use App\Models\Announcement;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Student;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * الإعلانُ يُوجَّه إلى فئةٍ أو أكثر (طلاب · أولياء أمور · أساتذة)، وإلى المعهد كلِّه أو حلقاتٍ بعينها.
 *
 * 🔑 والترشيحُ في الخادم: إعلانٌ لفئةٍ أخرى أو لحلقةٍ ليست له لا يصل جهازَه أصلاً. ولكل فئةٍ حلقاتُها: الطالب
 * بتسجيله، ووليُّ الأمر بتسجيل أبنائه، والأستاذ بما أُسند إليه.
 */
class AnnouncementAudienceTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_a_guardian_reads_only_what_is_aimed_at_guardians(): void
    {
        $this->actingAsGuardian();

        $this->publish(['title' => 'للطلاب', 'audience' => ['students']]);
        $this->publish(['title' => 'للأولياء', 'audience' => ['guardians']]);
        $this->publish(['title' => 'للأساتذة', 'audience' => ['teachers']]);

        $this->assertSame(['للأولياء'], $this->titles('/api/v1/guardian/announcements'));
    }

    public function test_an_announcement_can_aim_at_several_audiences_at_once(): void
    {
        $this->publish(['title' => 'للجميع', 'audience' => ['students', 'guardians', 'teachers']]);
        $this->publish(['title' => 'للأولياء والأساتذة', 'audience' => ['guardians', 'teachers']]);

        $this->actingAsGuardian();
        $this->assertEqualsCanonicalizing(['للجميع', 'للأولياء والأساتذة'], $this->titles('/api/v1/guardian/announcements'));

        $this->actingAsTeacher($this->institute);
        $this->assertEqualsCanonicalizing(['للجميع', 'للأولياء والأساتذة'], $this->titles('/api/v1/teacher/announcements'));

        $this->actingAsStudent();
        $this->assertSame(['للجميع'], $this->titles('/api/v1/student/me/announcements'));
    }

    /**
     * وليُّ الأمر يرى إعلان **حلقة ابنه** لا حلقةً لا ابنَ له فيها.
     */
    public function test_a_guardian_gets_the_circle_announcements_of_their_childrens_circles(): void
    {
        $guardian = $this->actingAsGuardian();
        $mine = $this->makeCourseCircle();
        $theirs = $this->makeCourseCircle();
        $child = $this->childOf($guardian);
        $this->enrol($child, $mine);

        $this->publish(['title' => 'حلقة ابني', 'audience' => ['guardians'], 'scope' => 'circle', 'scope_ids' => [$mine->id]]);
        $this->publish(['title' => 'حلقةٌ أخرى', 'audience' => ['guardians'], 'scope' => 'circle', 'scope_ids' => [$theirs->id]]);

        $this->assertSame(['حلقة ابني'], $this->titles('/api/v1/guardian/announcements'));
    }

    public function test_a_teacher_gets_the_announcements_of_the_circles_assigned_to_them(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        $mine = $this->makeCourseCircle();
        $theirs = $this->makeCourseCircle();
        CourseCircleTeacher::create(['course_circle_id' => $mine->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $this->publish(['title' => 'للمعهد', 'audience' => ['teachers']]);
        $this->publish(['title' => 'حلقتي', 'audience' => ['teachers'], 'scope' => 'circle', 'scope_ids' => [$mine->id]]);
        $this->publish(['title' => 'حلقةُ زميل', 'audience' => ['teachers'], 'scope' => 'circle', 'scope_ids' => [$theirs->id]]);
        $this->publish(['title' => 'لحلقتي لكن للطلاب', 'audience' => ['students'], 'scope' => 'circle', 'scope_ids' => [$mine->id]]);

        $this->assertEqualsCanonicalizing(['للمعهد', 'حلقتي'], $this->titles('/api/v1/teacher/announcements'));
    }

    /**
     * الإعلاناتُ التي سبقت الفئات كانت للطلاب فقط: بلا `audience` تبقى كذلك ولا تظهر لغيرهم.
     */
    public function test_an_announcement_written_before_audiences_stays_for_students_only(): void
    {
        $announcement = $this->publish(['title' => 'قديم']);
        $announcement->forceFill(['audience' => null])->saveQuietly();

        $this->actingAsStudent();
        $this->assertSame(['قديم'], $this->titles('/api/v1/student/me/announcements'));

        $this->actingAsGuardian();
        $this->assertSame([], $this->titles('/api/v1/guardian/announcements'));

        $this->actingAsTeacher($this->institute);
        $this->assertSame([], $this->titles('/api/v1/teacher/announcements'));
    }

    public function test_each_role_is_served_only_by_its_own_endpoint(): void
    {
        $this->actingAsGuardian();
        $this->getJson('/api/v1/teacher/announcements')->assertForbidden();

        $this->actingAsTeacher($this->institute);
        $this->getJson('/api/v1/guardian/announcements')->assertForbidden();
    }

    /**
     * @return array<int, string>
     */
    private function titles(string $url): array
    {
        return collect($this->getJson($url)->assertOk()->json('data'))->pluck('title')->all();
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function publish(array $attributes): Announcement
    {
        return Announcement::create([
            'institute_id' => $this->institute->id,
            'body' => 'نصُّ الإعلان.',
            'scope' => 'all',
            'audience' => ['students'],
            'published_at' => now()->subHour(),
            ...$attributes,
        ]);
    }

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

    private function childOf(Guardian $guardian): Student
    {
        $child = Student::factory()->create(['institute_id' => $this->institute->id]);

        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $child->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
            'can_view_reports' => true,
            'can_submit_excuses' => true,
        ]);

        return $child;
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
}
