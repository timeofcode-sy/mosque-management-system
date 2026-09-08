<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\ExcuseStatus;
use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Student;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * أنواعُ عملياتِ الإدارة اليومية في `sync/push` — ✅ م.6.2.
 *
 * هذه هي الأربعةُ التي تُكتب **في المسجد بلا شبكة**، ولذلك مرّت بالطابور لا بـREST
 * ([PHASE-6-STAGES.MD §3.1]): تسجيلُ طالب، والتسجيلُ في حلقة، والنقلُ بينها،
 * ومراجعةُ إذن الغياب — والأخيرةُ هي الفجوةُ المسمّاة في [APPS-FEATURES.md §4.2]
 * البند 4: كان في الأنواع `excuse.submit` (تقديمٌ) بلا مراجعة.
 */
class AdminOperationsTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle('حلقة الفرقان');
    }

    public function test_a_supervisor_registers_a_student_offline_and_enrolls_them_in_one_batch(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        // معرّفُ الطالب يولّده الجهاز، فيصفّ التسجيلَ ثم التسجيلَ في حلقة معاً بلا
        // انتظار معرّفٍ من الخادم — نفسُ قاعدة الجلسة في م.5.3.
        $studentUuid = (string) Str::uuid7();

        $response = $this->postJson('/api/v1/sync/push', [
            'operations' => [
                [
                    'op_uuid' => (string) Str::uuid7(),
                    'type' => 'student.save',
                    'uuid' => $studentUuid,
                    'student' => [
                        'first_name' => 'محمد',
                        'father_name' => 'خالد',
                        'family_name' => 'المصري',
                        'gender' => 'male',
                        'status' => 'active',
                        'registration_no' => '1042',
                    ],
                    'guardians' => [
                        'father' => ['full_name' => 'خالد المصري', 'phone' => '0900000000'],
                    ],
                ],
                [
                    'op_uuid' => (string) Str::uuid7(),
                    'type' => 'enrollment.save',
                    'student_uuid' => $studentUuid,
                    'course_circle_uuid' => $this->courseCircle->uuid,
                ],
            ],
        ])->assertOk();

        $this->assertCount(2, $response->json('applied'));
        $this->assertSame([], $response->json('failed'));

        $student = Student::query()->where('uuid', $studentUuid)->firstOrFail();

        $this->assertSame($this->institute->id, $student->institute_id);
        $this->assertSame('محمد', $student->first_name);
        $this->assertSame('خالد المصري', $student->father()?->full_name);

        $this->assertDatabaseHas('enrollments', [
            'student_id' => $student->id,
            'course_circle_id' => $this->courseCircle->id,
            'status' => EnrollmentStatus::Active->value,
        ]);
    }

    public function test_resending_student_save_with_the_same_uuid_edits_in_place(): void
    {
        $this->actingAsAdministrator($this->institute, 'supervisor');

        $studentUuid = (string) Str::uuid7();

        $save = fn (string $familyName): array => [
            'op_uuid' => (string) Str::uuid7(),
            'type' => 'student.save',
            'uuid' => $studentUuid,
            'student' => [
                'first_name' => 'محمد', 'father_name' => 'خالد',
                'family_name' => $familyName, 'gender' => 'male', 'status' => 'active',
            ],
        ];

        $this->postJson('/api/v1/sync/push', ['operations' => [$save('المصري')]])->assertOk();
        $this->postJson('/api/v1/sync/push', ['operations' => [$save('الحلبي')]])->assertOk();

        $this->assertSame(1, Student::query()->where('uuid', $studentUuid)->count());
        $this->assertSame('الحلبي', Student::query()->where('uuid', $studentUuid)->firstOrFail()->family_name);
    }

    public function test_student_save_resolves_traits_by_uuid_not_by_primary_key(): void
    {
        // الجهازُ لا يعرف المفاتيح الأساسية أصلاً: ما يصله في sync/pull معرّفاتٌ
        // عالمية وحدها.
        $trait = PersonalTrait::factory()->create(['institute_id' => $this->institute->id]);

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $studentUuid = (string) Str::uuid7();

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'student.save',
                'uuid' => $studentUuid,
                'student' => ['first_name' => 'أنس', 'father_name' => 'سعيد', 'family_name' => 'الدمشقي', 'gender' => 'male', 'status' => 'active'],
                'trait_uuids' => [$trait->uuid],
            ]],
        ])->assertOk()->assertJsonPath('failed', []);

        $student = Student::query()->where('uuid', $studentUuid)->firstOrFail();

        $this->assertDatabaseHas('student_trait', ['student_id' => $student->id, 'trait_id' => $trait->id]);
    }

    public function test_a_transfer_closes_the_old_enrollment_without_deleting_it(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $student->id]);

        $destination = $this->makeCourseCircle('حلقة النور');

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'student.transfer',
                'student_uuid' => $student->uuid,
                'to_course_circle_uuid' => $destination->uuid,
                'reason' => 'مستواه تقدّم',
            ]],
        ])->assertOk()->assertJsonPath('failed', []);

        $this->assertDatabaseHas('enrollments', [
            'student_id' => $student->id,
            'course_circle_id' => $this->courseCircle->id,
            'status' => EnrollmentStatus::Transferred->value,
        ]);
        $this->assertDatabaseHas('enrollments', [
            'student_id' => $student->id,
            'course_circle_id' => $destination->id,
            'status' => EnrollmentStatus::Active->value,
        ]);
        $this->assertDatabaseHas('student_transfers', ['student_id' => $student->id, 'reason' => 'مستواه تقدّم']);
    }

    public function test_approving_an_excuse_offline_turns_open_absences_into_excused(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $student->id]);

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'session_date' => '2026-09-09',
        ]);
        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => AttendanceStatus::Absent,
        ]);

        $excuse = AbsenceExcuse::factory()->create([
            'student_id' => $student->id,
            'from_date' => '2026-09-08',
            'to_date' => '2026-09-10',
            'status' => ExcuseStatus::Pending,
        ]);

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => (string) Str::uuid7(),
                'type' => 'excuse.review',
                'excuse_uuid' => $excuse->uuid,
                'decision' => 'approved',
                'note' => 'سفرٌ موثَّق',
            ]],
        ])->assertOk()->assertJsonPath('failed', []);

        $this->assertSame(ExcuseStatus::Approved, $excuse->refresh()->status);
        $this->assertSame(AttendanceStatus::Excused, Attendance::query()
            ->where('student_id', $student->id)
            ->firstOrFail()->status);
    }

    public function test_a_teacher_cannot_queue_an_administrative_operation(): void
    {
        // الطابور كان مفتوحاً لكل حاملِ sync.push، والأستاذُ يملكها ليتفقّد. فصار
        // لكل نوعٍ صلاحيتُه، والرفضُ يقع في failed[] لا على الدفعة كلِّها.
        $this->actingAsTeacher($this->institute);

        $opUuid = (string) Str::uuid7();

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => $opUuid,
                'type' => 'student.save',
                'uuid' => (string) Str::uuid7(),
                'student' => ['first_name' => 'طالب', 'father_name' => 'أب', 'family_name' => 'عائلة', 'gender' => 'male', 'status' => 'active'],
            ]],
        ])
            ->assertOk()
            ->assertJsonPath('failed.0.op_uuid', $opUuid);

        $this->assertDatabaseCount('students', 0);
    }

    public function test_amending_a_closed_session_needs_the_permission_that_sets_the_desktop_apart(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create(['course_circle_id' => $this->courseCircle->id, 'student_id' => $student->id]);

        $teacher = $this->actingAsTeacher($this->institute);
        $this->assertNotNull($teacher);

        $take = fn (): array => [
            'op_uuid' => (string) Str::uuid7(),
            'type' => 'attendance.take',
            'course_circle_uuid' => $this->courseCircle->uuid,
            'session_date' => '2026-09-09',
            'amend' => true,
            'attendances' => [['student_uuid' => $student->uuid, 'status' => 'present', 'recorded_at' => '2026-09-09 08:00:00']],
        ];

        $this->postJson('/api/v1/sync/push', ['operations' => [
            ['op_uuid' => (string) Str::uuid7(), 'type' => 'attendance.session.open', 'course_circle_uuid' => $this->courseCircle->uuid, 'session_date' => '2026-09-09'],
            $take(),
        ]])
            ->assertOk()
            ->assertJsonCount(1, 'failed');

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $this->postJson('/api/v1/sync/push', ['operations' => [$take()]])
            ->assertOk()
            ->assertJsonPath('failed', []);
    }

    public function test_an_administrative_operation_never_crosses_the_institute_boundary(): void
    {
        $other = Institute::factory()->create();
        $foreign = Student::factory()->create(['institute_id' => $other->id]);

        $this->actingAsAdministrator($this->institute, 'supervisor');

        $opUuid = (string) Str::uuid7();

        $this->postJson('/api/v1/sync/push', [
            'operations' => [[
                'op_uuid' => $opUuid,
                'type' => 'student.save',
                'uuid' => $foreign->uuid,
                'student' => ['first_name' => 'اختطاف', 'father_name' => 'أب', 'family_name' => 'عائلة', 'gender' => 'male', 'status' => 'active'],
            ]],
        ])
            ->assertOk()
            ->assertJsonPath('failed.0.op_uuid', $opUuid);

        $this->assertNotSame('اختطاف', $foreign->refresh()->first_name);
    }
}
