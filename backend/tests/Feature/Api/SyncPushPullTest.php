<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\RecitationGrade;
use App\Enums\TeacherRole;
use App\Models\ChangeLog;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentPoint;
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

        $this->assertSame(1, ChangeLog::query()
            ->where('table_name', 'attendance_sessions')
            ->where('row_uuid', $sessionUuid)
            ->where('operation', 'create')
            ->count());

        /**
         * صفُّ الحضور نفسه — لا صفُّ الجلسة وحده.
         *
         * كان الدفع يسجّل تغييراً واحداً على attendance_sessions، وحمولتُه لا تحمل حالات
         * الطلاب؛ فكان العميل يعرف أن الجلسة تغيّرت ولا يعرف بماذا. صار المراقب يسجّل كل
         * صفٍّ تغيّر بحمولته، وهذا ما يجعل sync/pull قابلاً للتطبيق على مخزن العميل.
         */
        $attendanceUuid = $this->courseCircle->attendanceSessions()->first()
            ->attendances()->where('student_id', $student->id)->sole()->uuid;

        $change = ChangeLog::query()
            ->where('table_name', 'attendances')
            ->where('row_uuid', $attendanceUuid)
            ->sole();

        $this->assertSame(AttendanceStatus::Present->value, $change->payload['status']);
        $this->assertSame($takeOp, $change->op_uuid);
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

    public function test_push_records_a_recitation_and_discretionary_points(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $student->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-06',
            ]],
        ])->assertOk();

        $sessionUuid = $this->courseCircle->attendanceSessions()->first()->uuid;

        $this->postJson('/api/v1/sync/push', [
            'operations' => [
                [
                    'op_uuid' => (string) Str::uuid7(),
                    'type' => 'recitation.save',
                    'session_uuid' => $sessionUuid,
                    'student_uuid' => $student->uuid,
                    'recitation' => [
                        'from_surah' => 67, 'from_ayah' => 1,
                        'to_surah' => 67, 'to_ayah' => 30,
                        'grade' => 'excellent', 'juz' => 29,
                    ],
                ],
                [
                    'op_uuid' => (string) Str::uuid7(),
                    'type' => 'points.award',
                    'session_uuid' => $sessionUuid,
                    'student_uuid' => $student->uuid,
                    'points' => -2,
                    'reason' => 'behavior',
                ],
            ],
        ])->assertOk();

        $log = MemorizationLog::query()->where('student_id', $student->id)->sole();
        $award = StudentPoint::query()->where('student_id', $student->id)->sole();

        $this->assertEqualsWithDelta(31.0, (float) $log->new_lines, 0.01);
        $this->assertEqualsWithDelta(-2.0, (float) $award->points, 0.01);

        $this->assertSame(1, ChangeLog::query()->where('table_name', 'memorization_logs')->count());
        $this->assertSame(1, ChangeLog::query()->where('table_name', 'student_points')->count());

        // الحذف يُسجَّل بدوره في السجل حتى يعرف العميل أن الصفّ زال.
        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'recitation.delete',
                'recitation_uuid' => $log->uuid,
            ]],
        ])->assertOk();

        $this->assertSoftDeleted($log);
        $this->assertSame(1, ChangeLog::query()->where('table_name', 'memorization_logs')->where('operation', 'delete')->count());
    }

    public function test_a_client_generated_uuid_turns_the_second_push_into_a_correction(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $student->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'attendance.session.open',
                'course_circle_uuid' => $this->courseCircle->uuid,
                'session_date' => '2026-09-06',
            ]],
        ])->assertOk();

        $sessionUuid = $this->courseCircle->attendanceSessions()->first()->uuid;
        $recitationUuid = (string) Str::uuid7();
        $pointUuid = (string) Str::uuid7();

        $push = fn (array $operations) => $this->postJson('/api/v1/sync/push', [
            'operations' => $operations,
        ])->assertOk();

        $recitation = fn (int $toAyah, string $grade) => [
            'op_uuid' => (string) Str::uuid7(),
            'type' => 'recitation.save',
            'session_uuid' => $sessionUuid,
            'student_uuid' => $student->uuid,
            'recitation' => [
                'uuid' => $recitationUuid,
                'from_surah' => 67, 'from_ayah' => 1,
                'to_surah' => 67, 'to_ayah' => $toAyah,
                'grade' => $grade, 'juz' => 29,
            ],
        ];

        $award = fn (float $points) => [
            'op_uuid' => (string) Str::uuid7(),
            'type' => 'points.award',
            'session_uuid' => $sessionUuid,
            'student_uuid' => $student->uuid,
            'uuid' => $pointUuid,
            'points' => $points,
            'reason' => 'behavior',
        ];

        $push([$recitation(30, 'excellent'), $award(-2)]);
        $push([$recitation(12, 'good'), $award(-5)]);

        // صفٌّ واحد لا صفّان: العميل أعاد إرسال معرّفه، فالثانيةُ تصحيحٌ لا تسجيلٌ ثانٍ.
        $log = MemorizationLog::query()->where('student_id', $student->id)->sole();
        $point = StudentPoint::query()->where('student_id', $student->id)->sole();

        $this->assertSame($recitationUuid, $log->uuid);
        $this->assertSame(12, $log->to_ayah);
        $this->assertSame(RecitationGrade::Good, $log->grade);
        $this->assertEqualsWithDelta(-5.0, (float) $point->points, 0.01);

        // ولا تُحسب الأسطر مكرّرةً لنفسها حين يُصحَّح السجلّ نفسه.
        $this->assertEqualsWithDelta(12.4, (float) $log->new_lines, 0.01);

        $push([
            [
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'points.delete',
                'point_uuid' => $pointUuid,
            ],
        ]);

        $this->assertSoftDeleted($point);
        $this->assertSame(1, ChangeLog::query()->where('table_name', 'student_points')->where('operation', 'delete')->count());
    }

    public function test_deleting_what_is_already_gone_is_applied_not_refused(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $opUuid = (string) Str::uuid7();

        // لو رُدّ هذا بـ404 لَعلق الطابورُ كلُّه خلف عمليةٍ لن تنجح أبداً — والنتيجة
        // المطلوبة منها (ألّا يبقى الصفّ) محقَّقةٌ أصلاً.
        $this->postJson('/api/v1/sync/push', [
            'operations' => [
                ['op_uuid' => $opUuid, 'type' => 'recitation.delete', 'recitation_uuid' => (string) Str::uuid7()],
                ['op_uuid' => (string) Str::uuid7(), 'type' => 'points.delete', 'point_uuid' => (string) Str::uuid7()],
            ],
        ])
            ->assertOk()
            ->assertJsonPath('applied.0', $opUuid);
    }

    public function test_pull_never_returns_changes_from_another_institute(): void
    {
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $foreignRowUuid = (string) Str::uuid7();

        ChangeLog::create([
            'table_name' => 'attendance_sessions',
            'row_uuid' => $foreignRowUuid,
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

        $rowUuids = collect($response->json('changes'))->pluck('row_uuid');

        $this->assertNotContains($foreignRowUuid, $rowUuids);
        $this->assertContains($this->courseCircle->attendanceSessions()->sole()->uuid, $rowUuids);
    }
}
