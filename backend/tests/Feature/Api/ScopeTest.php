<?php

namespace Tests\Feature\Api;

use App\Enums\GuardianRelation;
use App\Enums\TeacherRole;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * الأستاذ لا يسحب بيانات حلقة ليست له؛ ولي الأمر يرى أبناءه فقط.
 */
class ScopeTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_teacher_only_sees_circles_assigned_to_them(): void
    {
        $mine = $this->makeCourseCircle();
        $someoneElses = $this->makeCourseCircle();

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $mine->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $otherTeacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);
        CourseCircleTeacher::create(['course_circle_id' => $someoneElses->id, 'teacher_id' => $otherTeacher->id, 'role' => TeacherRole::Main]);

        $response = $this->getJson('/api/v1/teacher/circles');

        $response->assertOk();
        $uuids = collect($response->json('data'))->pluck('uuid')->all();

        $this->assertContains($mine->uuid, $uuids);
        $this->assertNotContains($someoneElses->uuid, $uuids);
    }

    public function test_teacher_from_another_institute_cannot_pull_this_institutes_changes(): void
    {
        $otherInstitute = Institute::factory()->create();
        $otherCourse = Course::factory()->current()->create(['institute_id' => $otherInstitute->id]);
        $otherShift = Shift::factory()->create(['course_id' => $otherCourse->id]);
        $otherCourseCircle = CourseCircle::factory()->create(['course_id' => $otherCourse->id, 'shift_id' => $otherShift->id]);

        $outsiderUser = User::factory()->create();
        $outsiderTeacher = Teacher::factory()->create(['institute_id' => $otherInstitute->id, 'user_id' => $outsiderUser->id]);
        CourseCircleTeacher::create(['course_circle_id' => $otherCourseCircle->id, 'teacher_id' => $outsiderTeacher->id, 'role' => TeacherRole::Main]);
        $this->assignInstituteRole($outsiderUser, $otherInstitute, 'teacher');
        Sanctum::actingAs($outsiderUser, ['*']);

        $mine = $this->makeCourseCircle();

        $response = $this->getJson('/api/v1/sync/pull?since=0&app=teacher');

        $response->assertOk();
        $this->assertCount(0, $response->json('changes'));

        $circles = $this->getJson('/api/v1/teacher/circles');
        $circles->assertOk();
        $this->assertNotContains($mine->uuid, collect($circles->json('data'))->pluck('uuid')->all());
    }

    public function test_guardian_only_sees_their_own_children(): void
    {
        $myChild = Student::factory()->create(['institute_id' => $this->institute->id]);
        $someoneElsesChild = Student::factory()->create(['institute_id' => $this->institute->id]);

        $guardian = Guardian::factory()->create(['institute_id' => $this->institute->id]);
        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $myChild->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
            'can_view_reports' => true,
            'can_submit_excuses' => true,
        ]);

        $user = User::factory()->create();
        $guardian->update(['user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('guardian');
        Sanctum::actingAs($user, ['*']);

        $response = $this->getJson('/api/v1/guardian/children');

        $response->assertOk();
        $uuids = collect($response->json('data'))->pluck('uuid')->all();

        $this->assertContains($myChild->uuid, $uuids);
        $this->assertNotContains($someoneElsesChild->uuid, $uuids);
    }

    public function test_guardian_cannot_fetch_attendance_for_a_child_that_is_not_theirs(): void
    {
        $someoneElsesChild = Student::factory()->create(['institute_id' => $this->institute->id]);

        $guardian = Guardian::factory()->create(['institute_id' => $this->institute->id]);
        $user = User::factory()->create();
        $guardian->update(['user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('guardian');
        Sanctum::actingAs($user, ['*']);

        $response = $this->getJson('/api/v1/guardian/children/'.$someoneElsesChild->uuid.'/attendance');

        $response->assertNotFound();
    }
}
