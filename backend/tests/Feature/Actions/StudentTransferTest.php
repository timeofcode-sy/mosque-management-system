<?php

namespace Tests\Feature\Actions;

use App\Actions\TransferStudent;
use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\Student;
use App\Models\StudentTransfer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use RuntimeException;
use Tests\TestCase;

class StudentTransferTest extends TestCase
{
    use RefreshDatabase;

    private Institute $institute;

    private Course $course;

    private CourseCircle $from;

    private CourseCircle $to;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->institute = Institute::factory()->create();
        $this->course = Course::factory()->current()->create(['institute_id' => $this->institute->id]);
        $shift = Shift::factory()->create(['course_id' => $this->course->id]);

        $this->from = CourseCircle::factory()->create(['course_id' => $this->course->id, 'shift_id' => $shift->id]);
        $this->to = CourseCircle::factory()->create(['course_id' => $this->course->id, 'shift_id' => $shift->id]);

        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);
    }

    public function test_transfer_closes_the_old_enrollment_and_opens_a_new_one(): void
    {
        $old = Enrollment::factory()->create([
            'course_circle_id' => $this->from->id,
            'student_id' => $this->student->id,
        ]);

        $new = app(TransferStudent::class)->handle($this->student, $this->to, 'الانتقال إلى مستوى أعلى');

        $this->assertSame(EnrollmentStatus::Transferred, $old->refresh()->status);
        $this->assertNotNull($old->left_on);

        $this->assertSame(EnrollmentStatus::Active, $new->status);
        $this->assertSame($this->to->id, $new->course_circle_id);
    }

    public function test_transfer_is_recorded_in_the_transfers_log(): void
    {
        Enrollment::factory()->create([
            'course_circle_id' => $this->from->id,
            'student_id' => $this->student->id,
        ]);

        $admin = User::factory()->create();

        app(TransferStudent::class)->handle($this->student, $this->to, 'اكتظاظ الحلقة', $admin);

        $transfer = StudentTransfer::query()->where('student_id', $this->student->id)->sole();

        $this->assertSame($this->from->id, $transfer->from_course_circle_id);
        $this->assertSame($this->to->id, $transfer->to_course_circle_id);
        $this->assertSame($this->course->id, $transfer->course_id);
        $this->assertSame('اكتظاظ الحلقة', $transfer->reason);
        $this->assertSame($admin->id, $transfer->performed_by);
    }

    public function test_the_student_disappears_from_the_old_circle_roster_but_keeps_the_attendance_history(): void
    {
        $old = Enrollment::factory()->create([
            'course_circle_id' => $this->from->id,
            'student_id' => $this->student->id,
        ]);

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $this->from->id,
            'session_date' => Carbon::today()->subDay(),
        ]);

        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $this->student->id,
            'enrollment_id' => $old->id,
            'status' => AttendanceStatus::Present,
        ]);

        app(TransferStudent::class)->handle($this->student, $this->to);

        $this->assertSame(0, $this->from->activeEnrollments()->count());
        $this->assertSame(1, $this->to->activeEnrollments()->count());

        $this->assertSame(1, $old->attendances()->count());
        $this->assertSame(1, $this->student->attendances()->count());
    }

    public function test_transferring_into_the_same_circle_is_rejected(): void
    {
        Enrollment::factory()->create([
            'course_circle_id' => $this->from->id,
            'student_id' => $this->student->id,
        ]);

        $this->expectException(RuntimeException::class);

        app(TransferStudent::class)->handle($this->student, $this->from);
    }

    public function test_transferring_a_student_with_no_enrollment_in_the_course_is_rejected(): void
    {
        $this->expectException(RuntimeException::class);

        app(TransferStudent::class)->handle($this->student, $this->to);
    }
}
