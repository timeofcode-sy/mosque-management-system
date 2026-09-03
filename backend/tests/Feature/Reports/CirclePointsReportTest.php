<?php

namespace Tests\Feature\Reports;

use App\Actions\BuildCirclePointsReport;
use App\Enums\EnrollmentStatus;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Support\DateRange;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class CirclePointsReportTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle('حلقة الفاروق');
    }

    public function test_the_rows_come_down_from_the_highest_total(): void
    {
        $first = $this->enroll('زيد');
        $second = $this->enroll('عمرو');

        $this->award($first, 10);
        $this->award($second, 4);

        $report = $this->build();

        $this->assertSame($first->id, $report['rows']->first()['student']->id);
        $this->assertSame(1, $report['rows']->first()['rank']);
        $this->assertSame(2, $report['rows']->last()['rank']);
        $this->assertEqualsWithDelta(14.0, $report['totals']['manual'], 0.01);
    }

    public function test_tied_students_share_a_rank(): void
    {
        $this->award($this->enroll('زيد'), 5);
        $this->award($this->enroll('عمرو'), 5);
        $this->award($this->enroll('بكر'), 1);

        $ranks = $this->build()['rows']->pluck('rank')->all();

        $this->assertSame([1, 1, 3], $ranks);
    }

    public function test_points_outside_the_range_are_left_out(): void
    {
        $student = $this->enroll('زيد');

        $this->award($student, 7, Carbon::today()->toDateString());
        $this->award($student, 99, Carbon::today()->subYear()->toDateString());

        $this->assertEqualsWithDelta(7.0, $this->build()['rows']->first()['total'], 0.01);
    }

    public function test_the_print_page_renders(): void
    {
        $this->award($this->enroll('زيد'), 3);

        $this->get(route('reports.print.points', ['courseCircle' => $this->courseCircle, 'range' => DateRange::WEEK]))
            ->assertOk()
            ->assertSee('تقرير نقاط الحلقة');
    }

    /**
     * @return array<string, mixed>
     */
    private function build(): array
    {
        return app(BuildCirclePointsReport::class)->handle(
            $this->courseCircle,
            DateRange::make(DateRange::WEEK, $this->course),
        );
    }

    private function enroll(string $name): Student
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id, 'first_name' => $name]);

        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => '2026-08-01',
        ]);

        return $student;
    }

    private function award(Student $student, float $points, ?string $on = null): void
    {
        StudentPoint::factory()->create([
            'student_id' => $student->id,
            'course_circle_id' => $this->courseCircle->id,
            'points' => $points,
            'awarded_on' => $on ?? Carbon::today()->toDateString(),
        ]);
    }
}
