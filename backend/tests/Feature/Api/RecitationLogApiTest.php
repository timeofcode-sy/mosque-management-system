<?php

namespace Tests\Feature\Api;

use App\Enums\GuardianRelation;
use App\Models\GuardianStudent;
use App\Models\MemorizationLog;
use App\Models\Student;
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
 * سجلُّ التسميع تحت شريط الأجزاء: الطالبُ يقرأ سجلَّه، ووليُّ الأمر سجلَّ ابنه وحده.
 */
class RecitationLogApiTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_a_student_reads_their_recitations_newest_first_with_surah_names(): void
    {
        $user = User::factory()->create();
        $student = Student::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $user->id]);
        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('student');
        Sanctum::actingAs($user, ['*']);

        MemorizationLog::factory()->create(['student_id' => $student->id, 'date' => '2026-10-01', 'from_surah' => 67, 'from_ayah' => 1, 'to_surah' => 67, 'to_ayah' => 15]);
        MemorizationLog::factory()->create(['student_id' => $student->id, 'date' => '2026-10-05', 'from_surah' => 78, 'from_ayah' => 1, 'to_surah' => 78, 'to_ayah' => 20]);
        MemorizationLog::factory()->create(['date' => '2026-10-06']);

        $rows = $this->getJson('/api/v1/student/me/recitations')->assertOk()->json('data');

        $this->assertCount(2, $rows);
        $this->assertSame('2026-10-05', $rows[0]['date']);
        $this->assertSame('الملك', $rows[1]['from_surah_name']);
        $this->assertNotNull($rows[0]['type_label']);
    }

    public function test_a_guardian_reads_only_their_own_childs_recitations(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = Student::factory()->create(['institute_id' => $this->institute->id]);
        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $child->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
            'can_view_reports' => true,
            'can_submit_excuses' => true,
        ]);
        $stranger = Student::factory()->create(['institute_id' => $this->institute->id]);
        MemorizationLog::factory()->create(['student_id' => $child->id]);

        $this->getJson("/api/v1/guardian/children/{$child->uuid}/recitations")->assertOk()->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/guardian/children/{$stranger->uuid}/recitations")->assertNotFound();
    }
}
