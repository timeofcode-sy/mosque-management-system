<?php

namespace Tests\Feature\Livewire;

use App\Actions\BuildStudentProgressMap;
use App\Actions\DeleteRecitation;
use App\Actions\SaveRecitation;
use App\Actions\SaveStudentCurriculumProgress;
use App\Enums\EnrollmentStatus;
use App\Enums\ProgressStatus;
use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\CurriculumItem;
use App\Models\Enrollment;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Support\SabrSettings;
use Database\Seeders\CurriculumSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class JuzProgressTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Student $student;

    private AttendanceSession $session;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->seed(CurriculumSeeder::class);

        $courseCircle = $this->makeCourseCircle();
        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $this->student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => '2026-08-01',
        ]);

        $this->session = AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => '2026-09-01',
            'status' => SessionStatus::Draft,
        ]);
    }

    public function test_a_memorized_juz_fills_its_surahs_on_the_mushaf_map(): void
    {
        $this->markJuz(1, memorized: true);

        $surahs = app(BuildStudentProgressMap::class)->handle($this->student)['surahs'];

        // الجزء الأول: الفاتحة كاملةً، والبقرة حتى الآية 141.
        $this->assertSame(7, $surahs[1]['covered']);
        $this->assertSame(141, $surahs[2]['covered']);
        $this->assertSame(0, $surahs[3]['covered']);
    }

    public function test_four_memorized_juz_reach_into_an_nisa(): void
    {
        foreach (range(1, 4) as $juz) {
            $this->markJuz($juz, memorized: true);
        }

        $map = app(BuildStudentProgressMap::class)->handle($this->student);

        $this->assertSame(1.0, $map['surahs'][2]['ratio']);
        $this->assertSame(1.0, $map['surahs'][3]['ratio']);
        $this->assertSame(23, $map['surahs'][4]['covered']);
        $this->assertSame(3, $map['completed_surahs']);
    }

    public function test_a_juz_percent_follows_its_recited_ayahs(): void
    {
        // الجزء الثلاثون 564 آية؛ النبأ 40 آية منها.
        $this->recite(78, 1, 78, 40);

        $progress = $this->progress(30);

        $this->assertSame(ProgressStatus::InProgress, $progress->status);
        $this->assertSame(intdiv(40 * 100, 564), $progress->percent);
    }

    public function test_reciting_every_ayah_of_a_juz_completes_it_awaiting_sabr(): void
    {
        $this->recite(1, 1, 2, 141);

        $progress = $this->progress(1);

        $this->assertSame(ProgressStatus::Memorized, $progress->status);
        $this->assertSame(100, $progress->percent);
        $this->assertNull($progress->score);
    }

    public function test_deleting_a_recitation_lowers_the_juz_percent(): void
    {
        $log = $this->recite(78, 1, 78, 40);

        app(DeleteRecitation::class)->handle($log);

        $progress = $this->progress(30);

        $this->assertSame(ProgressStatus::NotStarted, $progress->status);
        $this->assertSame(0, $progress->percent);
    }

    public function test_unmarking_a_juz_falls_back_to_its_recited_ayahs(): void
    {
        $this->recite(78, 1, 78, 40);
        $this->markJuz(30, memorized: true);

        $this->assertSame(100, $this->progress(30)->percent);

        $this->markJuz(30, memorized: false);

        $this->assertSame(ProgressStatus::InProgress, $this->progress(30)->status);
        $this->assertSame(intdiv(40 * 100, 564), $this->progress(30)->percent);
    }

    public function test_a_juz_cannot_be_mastered_only_memorized(): void
    {
        app(SaveStudentCurriculumProgress::class)->handle($this->student, $this->juz(2), ['status' => ProgressStatus::Mastered->value]);

        $this->assertSame(ProgressStatus::Memorized, $this->progress(2)->status);
    }

    public function test_the_sabr_score_is_judged_against_the_institute_pass_mark(): void
    {
        $this->markJuz(1, memorized: true, score: '78');

        $progress = $this->progress(1);
        $this->assertSame(78, $progress->score);
        $this->assertFalse(SabrSettings::for($this->institute)->passed($progress->score));

        $this->institute->update(['settings' => ['sabr' => ['pass_mark' => 75]]]);
        $this->assertTrue(SabrSettings::for($this->institute->refresh())->passed($progress->score));
    }

    public function test_the_juz_window_shows_its_bounds_and_coverage(): void
    {
        $this->recite(78, 1, 78, 40);

        Livewire::test('pages::students.show', ['student' => $this->student])
            ->call('editProgress', $this->juz(30)->getRouteKey())
            ->assertSee('النبأ 1 ← الناس 6')
            ->assertSeeHtml('data-test="juz-coverage"')
            ->assertSee('40 / 564');
    }

    public function test_a_sabr_score_above_one_hundred_is_rejected(): void
    {
        Livewire::test('pages::students.show', ['student' => $this->student])
            ->call('editProgress', $this->juz(1)->getRouteKey())
            ->set('progressMemorized', true)
            ->set('progressScore', '120')
            ->call('saveProgress')
            ->assertHasErrors('progressScore');
    }

    public function test_the_pass_mark_defaults_to_eighty_and_is_saved_with_the_institute(): void
    {
        $this->assertSame(80, SabrSettings::for($this->institute)->passMark());

        Livewire::test('pages::institute.edit')
            ->set('sabr.pass_mark', 70)
            ->call('save')
            ->assertHasNoErrors();

        $this->assertSame(70, SabrSettings::for($this->institute->refresh())->passMark());
    }

    private function markJuz(int $juz, bool $memorized, string $score = ''): void
    {
        Livewire::test('pages::students.show', ['student' => $this->student])
            ->call('editProgress', $this->juz($juz)->getRouteKey())
            ->set('progressMemorized', $memorized)
            ->set('progressScore', $score)
            ->call('saveProgress')
            ->assertHasNoErrors();
    }

    private function recite(int $fromSurah, int $fromAyah, int $toSurah, int $toAyah): MemorizationLog
    {
        return app(SaveRecitation::class)->handle($this->session, $this->student, [
            'from_surah' => $fromSurah,
            'from_ayah' => $fromAyah,
            'to_surah' => $toSurah,
            'to_ayah' => $toAyah,
        ], $this->admin);
    }

    private function progress(int $juz): StudentCurriculumProgress
    {
        return StudentCurriculumProgress::query()
            ->where('student_id', $this->student->id)
            ->where('curriculum_item_id', $this->juz($juz)->id)
            ->sole();
    }

    private function juz(int $juz): CurriculumItem
    {
        return CurriculumItem::query()->where('code', "juz-{$juz}")->sole();
    }
}
