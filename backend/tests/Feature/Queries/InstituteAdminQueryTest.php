<?php

namespace Tests\Feature\Queries;

use App\Enums\PointReason;
use App\Models\CircleDailyStat;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Queries\InstituteAdminQuery;
use App\Support\DateRange;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class InstituteAdminQueryTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Institute $second;

    private CourseCircle $secondCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->buildSecondInstitute();
    }

    public function test_the_overview_crosses_institutes(): void
    {
        $overview = app(InstituteAdminQuery::class)->overview(DateRange::make(DateRange::MONTH));

        $this->assertSame(2, $overview['totals']['institutes']);
        $this->assertEqualsCanonicalizing(
            [$this->institute->id, $this->second->id],
            collect($overview['rows'])->map(fn (array $row) => $row['institute']->id)->all(),
        );
    }

    public function test_each_institute_carries_its_own_attendance_rate(): void
    {
        $courseCircle = $this->makeCourseCircle();

        /** معهد الاختبار: 8 من 10 = 80% · المعهد الثاني: 5 من 10 = 50% */
        $this->recordDailyStat($courseCircle->id, present: 8, absent: 2);
        $this->recordDailyStat($this->secondCircle->id, present: 5, absent: 5);

        $rows = collect(app(InstituteAdminQuery::class)->overview(DateRange::make(DateRange::MONTH))['rows'])
            ->keyBy(fn (array $row) => $row['institute']->id);

        $this->assertSame(80.0, $rows[$this->institute->id]['rate']);
        $this->assertSame(50.0, $rows[$this->second->id]['rate']);
        $this->assertSame(65.0, app(InstituteAdminQuery::class)->overview(DateRange::make(DateRange::MONTH))['totals']['rate']);
    }

    public function test_points_are_summed_per_institute(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->second->id]);

        StudentPoint::factory()->create([
            'student_id' => $student->id,
            'points' => 12.5,
            'reason' => PointReason::Behavior,
            'awarded_on' => Carbon::today()->toDateString(),
        ]);

        $rows = collect(app(InstituteAdminQuery::class)->overview(DateRange::make(DateRange::MONTH))['rows'])
            ->keyBy(fn (array $row) => $row['institute']->id);

        $this->assertSame(12.5, $rows[$this->second->id]['points']);
        $this->assertSame(0.0, $rows[$this->institute->id]['points']);
    }

    /**
     * المطلوب استعلامات مجمّعة لا حلقةٌ على المعاهد: عددها لا يتغيّر بزيادة المعاهد.
     */
    public function test_the_overview_does_not_query_per_institute(): void
    {
        $baseline = $this->countQueriesOfOverview();

        Institute::factory()->count(4)->create();

        $this->assertSame($baseline, $this->countQueriesOfOverview());
    }

    public function test_the_list_counts_circles_students_and_teachers(): void
    {
        $this->makeCourseCircle();
        Student::factory()->count(3)->create(['institute_id' => $this->institute->id]);

        $row = app(InstituteAdminQuery::class)->list()->firstWhere('id', $this->institute->id);

        $this->assertSame(1, $row->circles_count);
        $this->assertSame(3, $row->students_count);
    }

    public function test_the_list_filters_by_name(): void
    {
        /** الاسمان صريحان بشقّيهما: الـ factory يختار من ستّة أسماء منها «الفرقان» */
        $this->institute->update(['name' => 'معهد النور', 'short_name' => 'النور']);
        $this->second->update(['name' => 'معهد الفرقان', 'short_name' => 'الفرقان']);

        $results = app(InstituteAdminQuery::class)->list('الفرقان');

        $this->assertCount(1, $results);
        $this->assertSame($this->second->id, $results->first()->id);
    }

    private function countQueriesOfOverview(): int
    {
        DB::flushQueryLog();
        DB::enableQueryLog();

        app(InstituteAdminQuery::class)->overview(DateRange::make(DateRange::MONTH));

        $count = count(DB::getRawQueryLog());
        DB::disableQueryLog();

        return $count;
    }

    private function buildSecondInstitute(): void
    {
        $this->second = Institute::factory()->create(['name' => 'المعهد الثاني']);

        $course = Course::factory()->current()->create(['institute_id' => $this->second->id]);
        $shift = Shift::factory()->create(['course_id' => $course->id]);

        $this->secondCircle = CourseCircle::factory()->create([
            'course_id' => $course->id,
            'shift_id' => $shift->id,
        ]);
    }

    private function recordDailyStat(int $courseCircleId, int $present, int $absent): void
    {
        CircleDailyStat::create([
            'course_circle_id' => $courseCircleId,
            'date' => Carbon::today()->toDateString(),
            'present' => $present,
            'absent' => $absent,
            'late' => 0,
            'excused' => 0,
            'total' => $present + $absent,
            'attendance_rate' => 0,
        ]);
    }
}
