<?php

namespace Tests\Feature\Api;

use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class StudentSelfTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_a_student_can_read_their_own_attendance_summary_and_progress(): void
    {
        $user = User::factory()->create();
        Student::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('student');
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/v1/student/me/attendance')
            ->assertOk()
            ->assertJsonStructure(['summary' => ['present', 'absent', 'late', 'excused', 'total', 'rate'], 'trend', 'recent']);

        $this->getJson('/api/v1/student/me/progress')
            ->assertOk()
            ->assertJsonStructure(['data']);
    }

    /**
     * 🔴 م.7.4 — نظيرُ عطبِ ولي الأمر: خريطةٌ فارغة تخرج مصفوفةً فيبدّل الحقلُ
     * نوعَه. وطالبٌ جديد بلا محفوظاتٍ هو الحالةُ الأغلب، وتطبيقُه يُبنى في م.8.
     */
    public function test_a_student_with_no_progress_gets_an_object_not_an_array(): void
    {
        $user = User::factory()->create();
        Student::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('student');
        Sanctum::actingAs($user, ['*']);

        $raw = $this->getJson('/api/v1/student/me/progress')->assertOk()->getContent();

        $this->assertStringContainsString('"data":{}', $raw);
        $this->assertStringNotContainsString('"data":[]', $raw);
    }

    public function test_a_non_student_account_is_rejected(): void
    {
        $user = User::factory()->create();
        Teacher::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('teacher');
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/v1/student/me/attendance')->assertForbidden();
    }
}
