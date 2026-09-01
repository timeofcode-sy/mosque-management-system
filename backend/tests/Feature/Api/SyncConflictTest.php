<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\TeacherRole;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\SyncConflict;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * جهازان يعدّلان نفس صفّ الحضور: الأحدث recorded_at يفوز، والقديم يُسجَّل في sync_conflicts.
 */
class SyncConflictTest extends TestCase
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

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-01',
            ]],
        ])->assertOk();
    }

    public function test_an_older_write_arriving_after_a_newer_one_is_rejected_and_logged(): void
    {
        $sessionUuid = $this->courseCircle->attendanceSessions()->first()->uuid;
        $deviceA = (string) Str::uuid7();
        $deviceB = (string) Str::uuid7();

        $this->postJson('/api/v1/sync/push', [
            'device_uuid' => $deviceA,
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.take',
                'session_uuid' => $sessionUuid,
                'attendances' => [[
                    'student_uuid' => $this->student->uuid,
                    'status' => AttendanceStatus::Present->value,
                    'recorded_at' => '2026-09-01 09:00:00',
                ]],
            ]],
        ])->assertOk();

        // جهاز ب يصل متأخراً بشبكة بطيئة، لكن كتب "غائب" قبل جهاز أ فعلياً (recorded_at أقدم).
        $this->postJson('/api/v1/sync/push', [
            'device_uuid' => $deviceB,
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.take',
                'session_uuid' => $sessionUuid,
                'attendances' => [[
                    'student_uuid' => $this->student->uuid,
                    'status' => AttendanceStatus::Absent->value,
                    'recorded_at' => '2026-09-01 08:00:00',
                ]],
            ]],
        ])->assertOk();

        $attendance = $this->courseCircle->attendanceSessions()->first()->attendances()->where('student_id', $this->student->id)->sole();

        $this->assertSame(AttendanceStatus::Present, $attendance->status);
        $this->assertSame(1, SyncConflict::query()->count());

        $conflict = SyncConflict::query()->sole();
        $this->assertSame($deviceB, $conflict->device_uuid);
        $this->assertSame('server_wins', $conflict->resolution);
    }

    public function test_a_newer_write_replaces_the_older_one_without_a_conflict(): void
    {
        $sessionUuid = $this->courseCircle->attendanceSessions()->first()->uuid;

        $this->postJson('/api/v1/sync/push', [
            'device_uuid' => (string) Str::uuid7(),
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.take',
                'session_uuid' => $sessionUuid,
                'attendances' => [[
                    'student_uuid' => $this->student->uuid,
                    'status' => AttendanceStatus::Absent->value,
                    'recorded_at' => '2026-09-01 08:00:00',
                ]],
            ]],
        ])->assertOk();

        $this->postJson('/api/v1/sync/push', [
            'device_uuid' => (string) Str::uuid7(),
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.take',
                'session_uuid' => $sessionUuid,
                'attendances' => [[
                    'student_uuid' => $this->student->uuid,
                    'status' => AttendanceStatus::Present->value,
                    'recorded_at' => '2026-09-01 09:00:00',
                ]],
            ]],
        ])->assertOk();

        $attendance = $this->courseCircle->attendanceSessions()->first()->attendances()->where('student_id', $this->student->id)->sole();

        $this->assertSame(AttendanceStatus::Present, $attendance->status);
        $this->assertSame(0, SyncConflict::query()->count());
    }
}
