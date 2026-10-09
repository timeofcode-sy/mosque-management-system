<?php

namespace Tests\Feature\Livewire;

use App\Enums\AttendanceStatus;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use App\Support\InstituteTheme;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * ألوان المعهد تُدخَل مرّةً في شاشة بياناته فتحكم اللوحةَ والتقاريرَ والتطبيقات معاً،
 * ودقائقُ التأخير تُملأ وحدها في شاشة التفقّد.
 */
class InstituteThemePanelTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle();
    }

    public function test_the_institute_screen_saves_the_three_colours_and_the_grace_period(): void
    {
        Livewire::test('pages::institute.edit')
            ->set('name', $this->institute->name)
            ->set('theme.primary', '#7D0A0A')
            ->set('theme.secondary', '#FFBF9B')
            ->set('theme.surface', '#EAD196')
            ->set('attendance.late_grace_minutes', 5)
            ->call('save')
            ->assertHasNoErrors();

        $settings = $this->institute->fresh()->settings;

        $this->assertSame('#7d0a0a', $settings['theme']['primary']);
        $this->assertSame(5, $settings['attendance']['late_grace_minutes']);

        // النقاط لم تُمسح بإضافة مفاتيح جديدة إلى نفس العمود.
        $this->assertArrayHasKey('points', $settings);
    }

    public function test_a_malformed_colour_is_refused_before_it_reaches_the_page(): void
    {
        Livewire::test('pages::institute.edit')
            ->set('name', $this->institute->name)
            ->set('theme.primary', 'red')
            ->call('save')
            ->assertHasErrors(['theme.primary']);
    }

    /**
     * الهوية البصرية v3 ثابتة: ألوان المعهد تبقى بياناتٍ في الإعدادات والـ API، لكنها لا تصبغ اللوحة
     * ولا التقارير، فيبقى التباين المضمون (4.5:1) في كل شاشة.
     */
    public function test_the_panel_stays_on_the_nuzuln_palette_whatever_the_institute_saved(): void
    {
        $this->institute->update(['settings' => [
            'theme' => ['primary' => '#7D0A0A', 'secondary' => '#FFBF9B', 'surface' => '#EAD196'],
        ]]);

        $this->get(route('dashboard'))
            ->assertOk()
            ->assertDontSee('#7d0a0a', escape: false)
            ->assertDontSee('--color-brand-600:', escape: false);
    }

    public function test_a_printed_report_stays_on_the_nuzuln_palette(): void
    {
        $this->institute->update(['settings' => [
            'theme' => ['primary' => '#7D0A0A', 'secondary' => '#FFBF9B', 'surface' => '#EAD196'],
        ]]);

        $this->get(route('reports.print.circle', ['courseCircle' => $this->courseCircle, 'date' => '2026-09-06']))
            ->assertOk()
            ->assertDontSee('#7d0a0a', escape: false);
    }

    public function test_marking_a_student_late_fills_the_minutes_before_saving(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $student->id,
            'enrolled_on' => '2026-09-01',
        ]);

        // الدوام يبدأ 08:00 (ShiftFactory)؛ الضغطة تقع 08:12.
        Carbon::setTestNow('2026-09-08 08:12:00');

        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-08')
            ->call('setStatus', $student->id, AttendanceStatus::Late->value);

        Carbon::setTestNow();

        // الرقم يظهر في الحقل فوراً — والأستاذ يعدّله إن شاء قبل الحفظ.
        $this->assertSame(12, $component->get("rows.{$student->id}.late_minutes"));
    }

    public function test_the_default_palette_stays_when_the_institute_sets_no_colours(): void
    {
        $this->assertTrue(InstituteTheme::for($this->institute)->isDefault());
    }
}
