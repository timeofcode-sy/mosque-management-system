<?php

namespace Tests\Feature\Models;

use App\Enums\AttendanceStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class AttendanceSessionTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_circle_cannot_have_two_sessions_on_the_same_day(): void
    {
        $courseCircle = CourseCircle::factory()->create();
        $date = Carbon::today();

        AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => $date,
        ]);

        $this->expectException(UniqueConstraintViolationException::class);

        AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => $date,
        ]);
    }

    public function test_a_student_is_recorded_once_per_session(): void
    {
        $enrollment = Enrollment::factory()->create();
        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $enrollment->course_circle_id,
        ]);

        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $enrollment->student_id,
            'enrollment_id' => $enrollment->id,
        ]);

        $this->expectException(UniqueConstraintViolationException::class);

        Attendance::factory()->absent()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $enrollment->student_id,
            'enrollment_id' => $enrollment->id,
        ]);
    }

    public function test_only_a_draft_session_is_editable(): void
    {
        $courseCircle = CourseCircle::factory()->create();

        $draft = AttendanceSession::factory()->create(['course_circle_id' => $courseCircle->id]);
        $completed = AttendanceSession::factory()->completed()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => Carbon::today()->subDay(),
        ]);
        $locked = AttendanceSession::factory()->locked()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => Carbon::today()->subDays(2),
        ]);

        $this->assertTrue($draft->isEditable());
        $this->assertFalse($completed->isEditable());
        $this->assertFalse($locked->isEditable());
    }

    public function test_attendance_statuses_are_cast_to_the_enum(): void
    {
        $enrollment = Enrollment::factory()->create();
        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $enrollment->course_circle_id,
        ]);

        $attendance = Attendance::factory()->late()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $enrollment->student_id,
            'enrollment_id' => $enrollment->id,
        ]);

        $this->assertSame(AttendanceStatus::Late, $attendance->fresh()->status);
        $this->assertSame('متأخّر', $attendance->status->label());
    }
}
