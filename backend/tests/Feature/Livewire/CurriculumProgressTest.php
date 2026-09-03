<?php

namespace Tests\Feature\Livewire;

use App\Actions\CalculateStudentPoints;
use App\Enums\ProgressStatus;
use App\Models\CurriculumItem;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use Database\Seeders\CurriculumSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class CurriculumProgressTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->seed(CurriculumSeeder::class);

        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);
    }

    public function test_marking_a_matn_mastered_awards_its_full_line_count(): void
    {
        $jazariyyah = $this->item('jazariyyah');

        $this->save($jazariyyah, ProgressStatus::Mastered);

        $progress = StudentCurriculumProgress::query()->where('curriculum_item_id', $jazariyyah->id)->sole();

        // المقدّمة الجزرية 107 أبيات × نقطة لكل بيت.
        $this->assertSame(100, $progress->percent);
        $this->assertEqualsWithDelta(107.0, (float) $progress->points, 0.01);
        $this->assertSame(Carbon::today()->toDateString(), $progress->achieved_on->toDateString());
    }

    public function test_a_partial_matn_takes_its_share(): void
    {
        $this->save($this->item('bayquniyyah'), ProgressStatus::InProgress, 50);

        $progress = StudentCurriculumProgress::query()->sole();

        // البيقونية 34 بيتاً؛ نصفها 17.
        $this->assertEqualsWithDelta(17.0, (float) $progress->points, 0.01);
    }

    public function test_a_hadith_item_uses_its_own_multiplier(): void
    {
        $this->save($this->item('arbaeen-1'), ProgressStatus::Memorized);

        // الأربعون النبوية (1) = 42 حديثاً × 5 نقاط افتراضياً.
        $this->assertEqualsWithDelta(210.0, (float) StudentCurriculumProgress::query()->sole()->points, 0.01);
    }

    public function test_the_progress_points_land_in_the_student_total(): void
    {
        $this->save($this->item('bayquniyyah'), ProgressStatus::Mastered);
        $this->save($this->item('arbaeen-1'), ProgressStatus::Mastered);

        $today = Carbon::today()->toDateString();
        $totals = app(CalculateStudentPoints::class)->handle($this->student, $today, $today);

        $this->assertEqualsWithDelta(34.0, $totals['mutun'], 0.01);
        $this->assertEqualsWithDelta(210.0, $totals['hadith'], 0.01);
        $this->assertEqualsWithDelta(244.0, $totals['total'], 0.01);
    }

    public function test_resetting_to_not_started_clears_the_points(): void
    {
        $item = $this->item('bayquniyyah');

        $this->save($item, ProgressStatus::Mastered);
        $this->save($item, ProgressStatus::NotStarted);

        $progress = StudentCurriculumProgress::query()->sole();

        $this->assertSame(0, $progress->percent);
        $this->assertEqualsWithDelta(0.0, (float) $progress->points, 0.01);
        $this->assertNull($progress->achieved_on);
    }

    private function save(CurriculumItem $item, ProgressStatus $status, int $percent = 0): void
    {
        Livewire::test('pages::students.show', ['student' => $this->student])
            ->call('editProgress', $item->getRouteKey())
            ->set('progressStatus', $status->value)
            ->set('progressPercent', $percent)
            ->call('saveProgress')
            ->assertHasNoErrors();
    }

    private function item(string $code): CurriculumItem
    {
        return CurriculumItem::query()->where('code', $code)->sole();
    }
}
