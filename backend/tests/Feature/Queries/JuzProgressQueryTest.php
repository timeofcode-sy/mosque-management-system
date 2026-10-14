<?php

namespace Tests\Feature\Queries;

use App\Enums\ProgressStatus;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Queries\JuzProgressQuery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * شريطُ الأجزاء: المحفوظُ والمتقَنُ محفوظ، والجاري الأكثرُ تقدّماً هو الحالي، وما ليس جزءاً خارجه.
 */
class JuzProgressQueryTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Curriculum $quran;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->quran = Curriculum::factory()->create(['institute_id' => $this->institute->id]);
    }

    private function progress(Student $student, string $code, ProgressStatus $status, int $percent = 0): void
    {
        $item = CurriculumItem::query()->firstOrCreate(
            ['curriculum_id' => $this->quran->id, 'code' => $code],
            ['name' => $code, 'sort_order' => 0, 'is_active' => true],
        );

        StudentCurriculumProgress::factory()->create([
            'student_id' => $student->id,
            'curriculum_item_id' => $item->id,
            'status' => $status,
            'percent' => $percent,
        ]);
    }

    public function test_memorised_mastered_and_the_most_advanced_juz_in_progress(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $other = Student::factory()->create(['institute_id' => $this->institute->id]);

        $this->progress($student, 'juz-30', ProgressStatus::Memorized, 100);
        $this->progress($student, 'juz-29', ProgressStatus::Mastered, 100);
        $this->progress($student, 'juz-28', ProgressStatus::InProgress, 20);
        $this->progress($student, 'juz-18', ProgressStatus::InProgress, 70);
        $this->progress($student, 'juz-1', ProgressStatus::NotStarted);
        $this->progress($student, 'nawawi', ProgressStatus::Memorized, 100);
        $this->progress($other, 'juz-30', ProgressStatus::InProgress, 10);

        $map = app(JuzProgressQuery::class)->forStudents([$student->id, $other->id]);

        $this->assertSame(['memorized' => [29, 30], 'current' => 18], $map[$student->id]);
        $this->assertSame(['memorized' => [], 'current' => 30], $map[$other->id]);
        $this->assertSame([], app(JuzProgressQuery::class)->forStudents([]));
    }

    public function test_the_student_page_and_the_circle_roster_draw_the_thirty_strokes(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $courseCircle = $this->makeCourseCircle('حلقة أبي بن كعب');
        Enrollment::factory()->create(['student_id' => $student->id, 'course_circle_id' => $courseCircle->id]);

        $this->progress($student, 'juz-30', ProgressStatus::Memorized, 100);
        $this->progress($student, 'juz-29', ProgressStatus::InProgress, 40);

        $this->get(route('students.show', $student))
            ->assertOk()
            ->assertSee('data-test="juz-progress"', false)
            ->assertSee('محفوظ 1 من 30 جزءًا')
            ->assertSee('يحفظ الآن: الجزء 29');

        $this->get(route('circles.show', $courseCircle))
            ->assertOk()
            ->assertSee('محفوظ 1 من 30 جزءًا، يحفظ الآن الجزء 29')
            ->assertSee('1/30');
    }
}
