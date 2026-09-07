<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\TeacherRole;
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

/**
 * العمليةُ المسمومة لا توقف الطابور — البند الرابع في [APPS-FEATURES.md §4.4].
 *
 * كانت الدفعة كتلةً واحدة: عمليةٌ ترفع استثناءً تُنهي الطلب كلَّه، فيبقى كلُّ ما بعدها
 * معلّقاً في الجهاز إلى الأبد لأن الأولى لن تنجح أبداً. ويزداد وزنُ ذلك بالديسكتوب:
 * جهازٌ ثانٍ يكتب بالتوازي فيَكثُر ما يُرفض.
 */
class PoisonedOperationTest extends TestCase
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
    }

    public function test_a_rejected_operation_does_not_stop_the_ones_behind_it(): void
    {
        $poison = (string) Str::uuid7();
        $open = (string) Str::uuid7();
        $take = (string) Str::uuid7();

        $response = $this->postJson('/api/v1/sync/push', [
            'operations' => [
                // جلسةٌ لا وجود لها ولا مفتاحَ طبيعي معها — مرفوضة يقيناً.
                ['op_uuid' => $poison, 'type' => 'attendance.session.complete', 'session_uuid' => (string) Str::uuid7()],
                ['op_uuid' => $open, 'type' => 'attendance.session.open', 'course_circle_uuid' => $this->courseCircle->uuid, 'session_date' => '2026-09-01'],
                ['op_uuid' => $take, 'type' => 'attendance.take', 'course_circle_uuid' => $this->courseCircle->uuid, 'session_date' => '2026-09-01', 'attendances' => [[
                    'student_uuid' => $this->student->uuid,
                    'status' => AttendanceStatus::Present->value,
                    'recorded_at' => '2026-09-01 08:05:00',
                ]]],
            ],
        ])->assertOk();

        $this->assertSame([$open, $take], $response->json('applied'));
        $this->assertSame($poison, $response->json('failed.0.op_uuid'));
        $this->assertNotEmpty($response->json('failed.0.message'));

        $this->assertDatabaseHas('attendances', [
            'student_id' => $this->student->id,
            'status' => AttendanceStatus::Present->value,
        ]);
    }

    public function test_an_unknown_operation_type_is_reported_not_thrown(): void
    {
        $unknown = (string) Str::uuid7();

        $this->postJson('/api/v1/sync/push', [
            'operations' => [['op_uuid' => $unknown, 'type' => 'attendance.teleport']],
        ])
            ->assertOk()
            ->assertJsonPath('failed.0.op_uuid', $unknown);
    }

    public function test_a_rejected_operation_leaves_no_half_written_row(): void
    {
        // المعاملة صارت لكل عملية على حدة، فرفضُ الثانية لا يُلغي أثر الأولى ولا
        // يُبقي أثراً جزئياً لنفسها.
        $this->postJson('/api/v1/sync/push', [
            'operations' => [
                ['op_uuid' => (string) Str::uuid7(), 'type' => 'attendance.session.open', 'course_circle_uuid' => $this->courseCircle->uuid, 'session_date' => '2026-09-02'],
                ['op_uuid' => (string) Str::uuid7(), 'type' => 'recitation.save', 'course_circle_uuid' => $this->courseCircle->uuid, 'session_date' => '2026-09-02', 'student_uuid' => (string) Str::uuid7(), 'recitation' => ['from_surah' => 1, 'from_ayah' => 1, 'to_surah' => 1, 'to_ayah' => 7]],
            ],
        ])
            ->assertOk()
            ->assertJsonCount(1, 'applied')
            ->assertJsonCount(1, 'failed');

        $this->assertDatabaseHas('attendance_sessions', ['course_circle_id' => $this->courseCircle->id]);
        $this->assertDatabaseCount('memorization_logs', 0);
    }
}
