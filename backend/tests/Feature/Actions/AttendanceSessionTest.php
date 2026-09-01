<?php

namespace Tests\Feature\Actions;

use App\Actions\CompleteAttendanceSession;
use App\Actions\LockAttendanceSession;
use App\Actions\OpenAttendanceSession;
use App\Actions\ReopenAttendanceSession;
use App\Actions\TakeAttendance;
use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\ExcuseStatus;
use App\Enums\SessionStatus;
use App\Models\AbsenceExcuse;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use RuntimeException;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class AttendanceSessionTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle();
    }

    public function test_opening_a_session_seeds_a_row_for_every_enrolled_student(): void
    {
        $this->enroll(3);

        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        $this->assertSame(SessionStatus::Draft, $session->status);
        $this->assertCount(3, $session->attendances);
        $this->assertSame(
            [AttendanceStatus::Present->value],
            $session->attendances->pluck('status')->map->value->unique()->values()->all(),
        );
    }

    public function test_opening_the_same_session_twice_does_not_duplicate_rows(): void
    {
        $this->enroll(2);

        app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        $this->assertSame(1, $this->courseCircle->attendanceSessions()->count());
        $this->assertCount(2, $session->attendances);
    }

    public function test_an_approved_excuse_pre_marks_the_student_as_excused(): void
    {
        $students = $this->enroll(2);

        AbsenceExcuse::factory()->create([
            'student_id' => $students->first()->id,
            'from_date' => '2026-08-31',
            'to_date' => '2026-09-02',
            'status' => ExcuseStatus::Approved,
        ]);

        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        $this->assertSame(
            AttendanceStatus::Excused,
            $session->attendances->firstWhere('student_id', $students->first()->id)->status,
        );
        $this->assertSame(
            AttendanceStatus::Present,
            $session->attendances->firstWhere('student_id', $students->last()->id)->status,
        );
    }

    public function test_a_student_who_left_before_the_date_is_not_seeded(): void
    {
        $stayed = $this->enroll(1)->first();
        $left = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $left->id,
            'status' => EnrollmentStatus::Transferred,
            'enrolled_on' => '2026-08-01',
            'left_on' => '2026-08-20',
        ]);

        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        $this->assertEqualsCanonicalizing([$stayed->id], $session->attendances->pluck('student_id')->all());
    }

    public function test_taking_attendance_writes_statuses_and_late_minutes(): void
    {
        $students = $this->enroll(2);
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        app(TakeAttendance::class)->handle($session, [
            $students->first()->id => ['status' => 'late', 'late_minutes' => 12, 'note' => 'زحام'],
            $students->last()->id => ['status' => 'absent'],
        ], $this->admin);

        $late = $session->refresh()->attendances->firstWhere('student_id', $students->first()->id);

        $this->assertSame(AttendanceStatus::Late, $late->status);
        $this->assertSame(12, $late->late_minutes);
        $this->assertSame('زحام', $late->note);
        $this->assertNull($session->attendances->firstWhere('student_id', $students->last()->id)->late_minutes);
    }

    public function test_completing_a_session_computes_the_daily_stat(): void
    {
        $students = $this->enroll(4);
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        app(TakeAttendance::class)->handle($session, [
            $students[0]->id => ['status' => 'present'],
            $students[1]->id => ['status' => 'late'],
            $students[2]->id => ['status' => 'absent'],
            $students[3]->id => ['status' => 'excused'],
        ], $this->admin);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        $stat = $this->courseCircle->dailyStats()->whereDate('date', '2026-09-01')->sole();

        // النسبة = (حاضر 1 + متأخّر 1) ÷ (المجموع 4 − المأذون 1) = 66.67٪
        $this->assertSame(1, $stat->present);
        $this->assertSame(1, $stat->late);
        $this->assertSame(1, $stat->absent);
        $this->assertSame(1, $stat->excused);
        $this->assertSame(4, $stat->total);
        $this->assertEqualsWithDelta(66.67, (float) $stat->attendance_rate, 0.01);
        $this->assertSame(1, $stat->daily_rank_in_shift);
    }

    public function test_a_completed_session_rejects_edits_until_reopened(): void
    {
        $students = $this->enroll(1);
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        try {
            app(TakeAttendance::class)->handle($session->refresh(), [
                $students->first()->id => ['status' => 'absent'],
            ], $this->admin);

            $this->fail('كان يجب رفض التعديل على جلسة مكتملة.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('مكتملة', $exception->getMessage());
        }

        $reopened = app(ReopenAttendanceSession::class)->handle($session->refresh());
        $this->assertSame(SessionStatus::Draft, $reopened->status);

        app(TakeAttendance::class)->handle($reopened, [
            $students->first()->id => ['status' => 'absent'],
        ], $this->admin);

        $this->assertSame(AttendanceStatus::Absent, $reopened->refresh()->attendances->sole()->status);
    }

    public function test_an_amend_may_edit_a_completed_session_without_reopening(): void
    {
        $students = $this->enroll(1);
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        app(TakeAttendance::class)->handle($session->refresh(), [
            $students->first()->id => ['status' => 'absent'],
        ], $this->admin, amend: true);

        $this->assertSame(AttendanceStatus::Absent, $session->refresh()->attendances->sole()->status);
    }

    public function test_a_locked_session_rejects_edits_and_cannot_be_reopened(): void
    {
        $students = $this->enroll(1);
        $session = app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);
        $locked = app(LockAttendanceSession::class)->handle($session->refresh());

        $this->assertSame(SessionStatus::Locked, $locked->status);

        $this->expectException(RuntimeException::class);
        app(TakeAttendance::class)->handle($locked, [
            $students->first()->id => ['status' => 'absent'],
        ], $this->admin, amend: true);
    }

    public function test_a_draft_session_produces_no_stats(): void
    {
        $this->enroll(2);
        app(OpenAttendanceSession::class)->handle($this->courseCircle, '2026-09-01', $this->admin);

        $this->assertSame(0, $this->courseCircle->dailyStats()->count());
    }

    /**
     * @return Collection<int, Student>
     */
    private function enroll(int $count): Collection
    {
        return collect(range(1, $count))->map(function () {
            $student = Student::factory()->create(['institute_id' => $this->institute->id]);

            Enrollment::factory()->create([
                'course_circle_id' => $this->courseCircle->id,
                'student_id' => $student->id,
                'status' => EnrollmentStatus::Active,
                'enrolled_on' => Carbon::parse('2026-08-01'),
            ]);

            return $student;
        });
    }
}
