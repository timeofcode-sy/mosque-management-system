<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\TeacherRole;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\Student;
use App\Models\SyncConflict;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * التعارضات على الـ API: يراها الديسكتوب ويحكم فيها كما تفعل اللوحة.
 *
 * الجدول لا يُزامَن ([SYNC-PROTOCOL.md §7])، فلا سبيل إليه إلا نقطةُ قراءةٍ مباشرة؛
 * والحكمُ متّصلٌ بطبعه فلا يمرّ بطابور المزامنة.
 */
class SyncConflictApiTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle();
        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $this->student->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $this->makeConflict();
    }

    public function test_a_supervisor_sees_the_pending_conflicts_of_their_institute(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $response = $this->getJson('/api/v1/sync/conflicts')->assertOk();

        $response->assertJsonCount(1, 'data');
        $this->assertSame('attendances', $response->json('data.0.table_name'));
        // القيمتان معاً — بلا الاثنتين لا يكون الحكم حكماً.
        $this->assertSame(AttendanceStatus::Absent->value, $response->json('data.0.client_payload.status'));
        $this->assertSame(AttendanceStatus::Present->value, $response->json('data.0.server_payload.status'));
    }

    public function test_conflicts_of_another_institute_are_not_visible(): void
    {
        $other = Institute::factory()->create();
        SyncConflict::create([
            'institute_id' => $other->id,
            'table_name' => 'attendances',
            'row_uuid' => (string) Str::uuid7(),
            'server_payload' => [],
            'client_payload' => [],
        ]);

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->getJson('/api/v1/sync/conflicts')->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_overturning_writes_the_device_value_back(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');
        $conflict = SyncConflict::query()->sole();

        $this->postJson('/api/v1/sync/conflicts/'.$conflict->uuid.'/resolve', ['decision' => 'client_wins'])
            ->assertOk()
            ->assertJsonPath('data.resolution', 'client_wins');

        $attendance = $this->courseCircle->attendanceSessions()->first()
            ->attendances()->where('student_id', $this->student->id)->sole();

        $this->assertSame(AttendanceStatus::Absent, $attendance->status);
        $this->assertNotNull($conflict->refresh()->resolved_at);
    }

    public function test_keeping_the_server_value_stamps_the_conflict_without_writing(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');
        $conflict = SyncConflict::query()->sole();

        $this->postJson('/api/v1/sync/conflicts/'.$conflict->uuid.'/resolve', ['decision' => 'server_wins'])
            ->assertOk();

        $attendance = $this->courseCircle->attendanceSessions()->first()
            ->attendances()->where('student_id', $this->student->id)->sole();

        $this->assertSame(AttendanceStatus::Present, $attendance->status);
        $this->assertNotNull($conflict->refresh()->resolved_at);
    }

    public function test_a_teacher_may_not_review_conflicts(): void
    {
        // الأستاذ يملك sync.push ولا يملك conflicts.review — والفرقُ مقصود.
        $this->actingAsTeacher($this->institute);

        $this->getJson('/api/v1/sync/conflicts')->assertForbidden();
    }

    public function test_a_conflict_uuid_from_another_institute_is_a_404(): void
    {
        $other = Institute::factory()->create();
        $foreign = SyncConflict::create([
            'institute_id' => $other->id,
            'table_name' => 'attendances',
            'row_uuid' => (string) Str::uuid7(),
            'server_payload' => [],
            'client_payload' => [],
        ]);

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/sync/conflicts/'.$foreign->uuid.'/resolve', ['decision' => 'server_wins'])
            ->assertNotFound();
    }

    /**
     * جهازان على نفس الصفّ: الأحدث يفوز، والمرفوض يُسجَّل تعارضاً.
     */
    private function makeConflict(): void
    {
        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-01',
            ]],
        ])->assertOk();

        $sessionUuid = $this->courseCircle->attendanceSessions()->first()->uuid;

        foreach ([['present', '09:00:00'], ['absent', '08:00:00']] as [$status, $time]) {
            $this->postJson('/api/v1/sync/push', [
                'device_uuid' => (string) Str::uuid7(),
                'operations' => [[
                    'op_uuid' => (string) Str::uuid7(),
                    'type' => 'attendance.take',
                    'session_uuid' => $sessionUuid,
                    'attendances' => [[
                        'student_uuid' => $this->student->uuid,
                        'status' => $status,
                        'recorded_at' => "2026-09-01 {$time}",
                    ]],
                ]],
            ])->assertOk();
        }
    }
}
