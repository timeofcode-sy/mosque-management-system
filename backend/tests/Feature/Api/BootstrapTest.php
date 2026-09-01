<?php

namespace Tests\Feature\Api;

use App\Enums\TeacherRole;
use App\Models\CourseCircleTeacher;
use App\Models\Guardian;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class BootstrapTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_bootstrap_returns_institute_course_and_the_teachers_circles(): void
    {
        $courseCircle = $this->makeCourseCircle('حلقة البداية');
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $response = $this->getJson('/api/v1/bootstrap');

        $response->assertOk();
        $response->assertJsonPath('institute.uuid', $this->institute->uuid);
        $response->assertJsonPath('course.uuid', $this->course->uuid);
        $this->assertContains($courseCircle->uuid, collect($response->json('circles'))->pluck('uuid')->all());
    }

    public function test_bootstrap_returns_no_circles_for_a_non_teacher_account(): void
    {
        $user = User::factory()->create();
        Guardian::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('guardian');
        Sanctum::actingAs($user, ['*']);

        $response = $this->getJson('/api/v1/bootstrap');

        $response->assertOk();
        $this->assertSame([], $response->json('circles'));
    }
}
