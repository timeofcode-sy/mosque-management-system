<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\TeacherRole;
use App\Models\ChangeLog;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Student;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class SyncPushPullTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle();
    }

    public function test_push_open_session_then_take_attendance_creates_change_log_rows(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $student->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $openOp = (string) Str::uuid7();

        $this->postJson('/api/v1/sync/push', [
            'device_uuid' => (string) Str::uuid7(),
            'operations' => [[
                'op_uuid' => $openOp,
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-01',
            ]],
        ])->assertOk();

        $sessionUuid = $this->courseCircle->attendanceSessions()->first()->uuid;
        $takeOp = (string) Str::uuid7();

        $response = $this->postJson('/api/v1/sync/push', [
            'device_uuid' => (string) Str::uuid7(),
            'operations' => [[
                'op_uuid' => $takeOp,
                'type' => 'attendance.take',
                'session_uuid' => $sessionUuid,
                'attendances' => [
                    ['student_uuid' => $student->uuid, 'status' => AttendanceStatus::Present->value],
                ],
            ]],
        ]);

        $response->assertOk();
        $response->assertJson(['applied' => [$takeOp], 'skipped' => []]);
        $this->assertSame(2, ChangeLog::query()->count());
    }

    public function test_resending_the_same_op_uuid_is_ignored(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $opUuid = (string) Str::uuid7();

        $payload = [
            'device_uuid' => (string) Str::uuid7(),
            'operations' => [[
                'op_uuid' => $opUuid,
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-02',
            ]],
        ];

        $first = $this->postJson('/api/v1/sync/push', $payload);
        $second = $this->postJson('/api/v1/sync/push', $payload);

        $first->assertOk()->assertJson(['applied' => [$opUuid], 'skipped' => []]);
        $second->assertOk()->assertJson(['applied' => [], 'skipped' => [$opUuid]]);
        $this->assertSame(1, ChangeLog::query()->where('op_uuid', $opUuid)->count());
        $this->assertSame(1, $this->courseCircle->attendanceSessions()->count());
    }

    public function test_pull_returns_only_changes_after_since_and_updates_the_device_cursor(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-03',
            ]],
        ])->assertOk();

        $firstSeq = ChangeLog::query()->max('id');

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-04',
            ]],
        ])->assertOk();

        $response = $this->getJson('/api/v1/sync/pull?since='.$firstSeq.'&app=teacher&device_uuid='.((string) Str::uuid7()));

        $response->assertOk();
        $changes = $response->json('changes');

        $this->assertCount(1, $changes);
        $this->assertGreaterThan($firstSeq, $response->json('server_seq'));
    }

    public function test_pull_never_returns_changes_from_another_institute(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        ChangeLog::create([
            'table_name' => 'attendance_sessions',
            'row_uuid' => (string) Str::uuid7(),
            'operation' => 'create',
            'scope_key' => 'institute:'.Str::uuid7(),
            'op_uuid' => (string) Str::uuid7(),
            'created_at' => now(),
        ]);

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-05',
            ]],
        ])->assertOk();

        $response = $this->getJson('/api/v1/sync/pull?since=0&app=teacher');

        $response->assertOk();
        $this->assertCount(1, $response->json('changes'));
        $this->assertSame('attendance_sessions', $response->json('changes.0.table_name'));
    }
}
