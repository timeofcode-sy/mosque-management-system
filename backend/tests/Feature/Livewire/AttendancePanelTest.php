<?php

namespace Tests\Feature\Livewire;

use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\ExcuseStatus;
use App\Enums\SessionStatus;
use App\Models\AbsenceExcuse;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Student;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class AttendancePanelTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle('حلقة الفاروق');
    }

    public function test_every_phase_three_screen_renders(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        foreach ([
            route('attendance.index'),
            route('attendance.take', $this->courseCircle),
            route('excuses.index'),
            route('reports.index'),
            route('stats.index'),
            route('reports.print.points', $this->courseCircle),
            route('reports.print.circle', $this->courseCircle),
            route('reports.print.shift', $this->shift),
            route('reports.print.student', $student),
        ] as $url) {
            $this->get($url)->assertOk();
        }
    }

    public function test_guests_are_turned_away_from_the_attendance_screens(): void
    {
        auth()->logout();
        session()->forget('institute_id');

        $this->get(route('attendance.index'))->assertRedirect(route('login'));
        $this->get(route('excuses.index'))->assertRedirect(route('login'));
        $this->get(route('reports.index'))->assertRedirect(route('login'));
    }

    public function test_the_board_lists_circles_scheduled_on_the_chosen_weekday(): void
    {
        // الدوام يعمل الأحد (0) والثلاثاء (2) — انظر BuildsInstitute.
        $sunday = Carbon::parse('2026-09-06')->toDateString();

        Livewire::test('pages::attendance.index')
            ->set('date', $sunday)
            ->assertSee('حلقة الفاروق')
            ->assertSee('الأحد');
    }

    public function test_taking_attendance_from_the_screen_saves_and_completes(): void
    {
        $students = $this->enroll(3);

        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01');

        $component
            ->call('setStatus', $students[0]->id, 'present')
            ->call('setStatus', $students[1]->id, 'absent')
            ->call('setStatus', $students[2]->id, 'late')
            ->set("rows.{$students[2]->id}.late_minutes", 5)
            ->call('complete')
            ->assertHasNoErrors();

        $session = $this->courseCircle->attendanceSessions()->whereDate('session_date', '2026-09-01')->sole();

        $this->assertSame(SessionStatus::Completed, $session->status);
        $this->assertSame(AttendanceStatus::Absent, $session->attendances->firstWhere('student_id', $students[1]->id)->status);
        $this->assertSame(5, $session->attendances->firstWhere('student_id', $students[2]->id)->late_minutes);

        $stat = $this->courseCircle->dailyStats()->whereDate('date', '2026-09-01')->sole();
        $this->assertEqualsWithDelta(66.67, (float) $stat->attendance_rate, 0.01);
    }

    public function test_mark_all_sets_every_student_at_once(): void
    {
        $students = $this->enroll(3);

        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('markAll', 'absent');

        foreach ($students as $student) {
            $this->assertSame('absent', $component->get('rows')[$student->id]['status']);
        }
    }

    public function test_a_locked_session_is_read_only_on_the_screen(): void
    {
        $students = $this->enroll(1);

        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('complete')
            ->call('lock');

        $this->assertFalse($component->instance()->editable());

        $component->call('setStatus', $students->first()->id, 'absent');

        $this->assertSame('present', $component->get('rows')[$students->first()->id]['status']);
    }

    public function test_the_screen_flags_a_retroactive_day_outside_the_shift(): void
    {
        // الاثنين (1) ليس من أيام الدوام (الأحد والثلاثاء).
        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', Carbon::parse('2026-09-07')->toDateString());

        $this->assertStringContainsString('استدراكي', (string) $component->instance()->weekdayNotice());
    }

    public function test_teacher_attendance_is_recorded_alongside_the_students(): void
    {
        $this->enroll(1);

        $assignment = CourseCircleTeacher::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'joined_on' => '2026-08-01',
            'left_on' => null,
        ]);

        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('setTeacherStatus', $assignment->teacher_id, 'late')
            ->call('save');

        $session = $this->courseCircle->attendanceSessions()->whereDate('session_date', '2026-09-01')->sole();
        $recorded = $session->teacherAttendances()->where('teacher_id', $assignment->teacher_id)->sole();

        $this->assertSame(AttendanceStatus::Late, $recorded->status);
        $this->assertSame(0, $component->get('errors')?->count() ?? 0);
    }

    public function test_an_excuse_can_be_submitted_and_approved_from_the_screen(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::excuses.index')
            ->call('create')
            ->set('studentId', $student->id)
            ->set('from_date', '2026-09-01')
            ->set('to_date', '2026-09-03')
            ->set('reason', 'سفر عائلي')
            ->call('save')
            ->assertHasNoErrors();

        $excuse = AbsenceExcuse::query()->where('student_id', $student->id)->sole();
        $this->assertSame(ExcuseStatus::Pending, $excuse->status);

        Livewire::test('pages::excuses.index')
            ->call('startReview', $excuse->getRouteKey())
            ->set('reviewNote', 'مقبول')
            ->call('decide', 'approved');

        $this->assertSame(ExcuseStatus::Approved, $excuse->refresh()->status);
        $this->assertSame($this->admin->id, $excuse->reviewed_by);
    }

    public function test_the_excuse_form_rejects_an_end_date_before_the_start(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::excuses.index')
            ->call('create')
            ->set('studentId', $student->id)
            ->set('from_date', '2026-09-05')
            ->set('to_date', '2026-09-01')
            ->set('reason', 'سفر')
            ->call('save')
            ->assertHasErrors('to_date');
    }

    public function test_the_circle_report_carries_the_day_numbers(): void
    {
        $students = $this->enroll(2);

        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('setStatus', $students[0]->id, 'present')
            ->call('setStatus', $students[1]->id, 'absent')
            ->call('complete');

        $variables = Livewire::test('pages::reports.index')
            ->set('date', '2026-09-01')
            ->set('courseCircleId', (string) $this->courseCircle->id)
            ->instance()
            ->circleReport()['variables'];

        $this->assertSame('حلقة الفاروق', $variables['circle_name']);
        $this->assertSame('1', $variables['present']);
        $this->assertSame('1', $variables['absent']);
        $this->assertSame('50%', $variables['rate']);
    }

    public function test_the_ranking_row_carries_a_trail_of_recent_rates(): void
    {
        $students = $this->enroll(2);
        $today = Carbon::today()->toDateString();

        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', $today)
            ->call('setStatus', $students[0]->id, 'present')
            ->call('setStatus', $students[1]->id, 'absent')
            ->call('complete');

        $row = Livewire::test('pages::reports.index')
            ->set('date', $today)
            ->instance()
            ->ranking()
            ->firstWhere('id', $this->courseCircle->id);

        $this->assertSame([50.0], $row->recent_rates);
    }

    public function test_the_dashboard_shows_the_attendance_rate_after_a_session_closes(): void
    {
        $students = $this->enroll(2);

        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', Carbon::today()->toDateString())
            ->call('setStatus', $students[0]->id, 'present')
            ->call('setStatus', $students[1]->id, 'absent')
            ->call('complete');

        $this->assertSame(50.0, Livewire::test('pages::dashboard')->instance()->todayRate());
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
                'enrolled_on' => '2026-08-01',
            ]);

            return $student;
        })->values();
    }
}
