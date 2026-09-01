<?php

namespace Tests\Feature\Actions;

use App\Actions\ActivateCourse;
use App\Actions\CloneCourseCircles;
use App\Enums\AttendanceStatus;
use App\Enums\TeacherRole;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\ShiftDay;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

/**
 * الدورة الجديدة تبدأ بعدّادات صفرية بينما يبقى سجل الدورة السابقة كاملاً وقابلاً للاستعلام.
 */
class CourseResetTest extends TestCase
{
    use RefreshDatabase;

    private Institute $institute;

    private Course $previous;

    private CourseCircle $previousCircle;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->institute = Institute::factory()->create();

        $this->previous = Course::factory()->current()->create([
            'institute_id' => $this->institute->id,
            'name' => 'دورة الشتاء',
        ]);

        $shift = Shift::factory()->create(['course_id' => $this->previous->id]);
        ShiftDay::factory()->create(['shift_id' => $shift->id, 'weekday' => 0]);
        ShiftDay::factory()->create(['shift_id' => $shift->id, 'weekday' => 2]);

        $this->previousCircle = CourseCircle::factory()->create([
            'course_id' => $this->previous->id,
            'shift_id' => $shift->id,
        ]);

        CourseCircleTeacher::create([
            'course_circle_id' => $this->previousCircle->id,
            'teacher_id' => Teacher::factory()->create(['institute_id' => $this->institute->id])->id,
            'role' => TeacherRole::Main,
            'joined_on' => $this->previous->starts_on,
        ]);

        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $enrollment = Enrollment::factory()->create([
            'course_circle_id' => $this->previousCircle->id,
            'student_id' => $this->student->id,
        ]);

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $this->previousCircle->id,
            'session_date' => Carbon::today()->subWeek(),
        ]);

        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $this->student->id,
            'enrollment_id' => $enrollment->id,
            'status' => AttendanceStatus::Absent,
        ]);
    }

    public function test_cloning_copies_the_structure_without_enrollments_or_attendance(): void
    {
        $next = Course::factory()->create(['institute_id' => $this->institute->id, 'name' => 'دورة الصيف']);

        $result = app(CloneCourseCircles::class)->handle($this->previous, $next);

        $this->assertSame(['shifts' => 1, 'circles' => 1, 'teachers' => 1], $result);

        $clone = $next->courseCircles()->sole();

        $this->assertSame($this->previousCircle->circle_id, $clone->circle_id);
        $this->assertNotSame($this->previousCircle->shift_id, $clone->shift_id);
        $this->assertSame(0, $clone->enrollments()->count());
        $this->assertSame(0, $clone->attendanceSessions()->count());
        $this->assertSame(1, $clone->courseCircleTeachers()->count());
    }

    public function test_the_cloned_shift_keeps_its_weekly_days(): void
    {
        $next = Course::factory()->create(['institute_id' => $this->institute->id]);

        app(CloneCourseCircles::class)->handle($this->previous, $next);

        $this->assertSame([0, 2], $next->shifts()->sole()->weekdays());
    }

    public function test_absence_counters_start_at_zero_while_the_previous_course_record_survives(): void
    {
        $next = Course::factory()->create(['institute_id' => $this->institute->id]);
        app(CloneCourseCircles::class)->handle($this->previous, $next);
        app(ActivateCourse::class)->handle($next);

        $absencesInNewCourse = Attendance::query()
            ->where('student_id', $this->student->id)
            ->whereHas('attendanceSession.courseCircle', fn ($query) => $query->where('course_id', $next->id))
            ->count();

        $absencesInPreviousCourse = Attendance::query()
            ->where('student_id', $this->student->id)
            ->whereHas('attendanceSession.courseCircle', fn ($query) => $query->where('course_id', $this->previous->id))
            ->count();

        $this->assertSame(0, $absencesInNewCourse);
        $this->assertSame(1, $absencesInPreviousCourse);

        $this->assertSame(1, $this->student->enrollments()->count());
    }

    public function test_activating_a_course_demotes_the_previous_current_one(): void
    {
        $next = Course::factory()->create(['institute_id' => $this->institute->id]);

        app(ActivateCourse::class)->handle($next);

        $this->assertTrue($next->refresh()->is_current);
        $this->assertFalse($this->previous->refresh()->is_current);
    }

    public function test_cloning_twice_does_not_duplicate_circles(): void
    {
        $next = Course::factory()->create(['institute_id' => $this->institute->id]);

        app(CloneCourseCircles::class)->handle($this->previous, $next);
        $second = app(CloneCourseCircles::class)->handle($this->previous, $next);

        $this->assertSame(0, $second['circles']);
        $this->assertSame(1, $next->courseCircles()->count());
        $this->assertSame(1, $next->shifts()->count());
    }
}
