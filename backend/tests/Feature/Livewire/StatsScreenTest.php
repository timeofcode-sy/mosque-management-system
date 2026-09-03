<?php

namespace Tests\Feature\Livewire;

use App\Enums\AttendanceStatus;
use App\Enums\EnrollmentStatus;
use App\Enums\NotePolarity;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Enrollment;
use App\Models\Student;
use App\Queries\StatsQuery;
use App\Support\DateRange;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class StatsScreenTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();

        $courseCircle = $this->makeCourseCircle('حلقة الفاروق');
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => '2026-08-01',
        ]);

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => Carbon::today()->toDateString(),
            'status' => SessionStatus::Completed,
        ]);

        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => AttendanceStatus::Present,
            'note' => 'أدب حسن',
            'note_polarity' => NotePolarity::Positive,
        ]);
    }

    public function test_every_filter_combination_renders(): void
    {
        foreach (array_keys(StatsQuery::entities()) as $entity) {
            foreach (array_keys(StatsQuery::metrics()) as $metric) {
                foreach ([DateRange::WEEK, DateRange::MONTH, DateRange::COURSE] as $range) {
                    Livewire::test('pages::stats.index')
                        ->set('entity', $entity)
                        ->set('metric', $metric)
                        ->set('range', $range)
                        ->assertOk()
                        ->assertSee(StatsQuery::metrics()[$metric]);
                }
            }
        }
    }

    public function test_the_two_boards_read_the_same_list_from_both_ends(): void
    {
        $component = Livewire::test('pages::stats.index')
            ->set('entity', StatsQuery::ENTITY_CIRCLES)
            ->set('metric', StatsQuery::METRIC_ATTENDANCE)
            ->instance();

        $this->assertSame(
            $component->top()->pluck('id')->reverse()->values()->all(),
            $component->bottom()->pluck('id')->all(),
        );
    }
}
