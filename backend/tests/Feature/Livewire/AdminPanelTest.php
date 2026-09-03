<?php

namespace Tests\Feature\Livewire;

use App\Enums\CourseStatus;
use App\Enums\EnrollmentStatus;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Curriculum;
use App\Models\CustomField;
use App\Models\Enrollment;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Shift;
use App\Models\Student;
use App\Models\StudentTransfer;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class AdminPanelTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_every_admin_screen_renders(): void
    {
        $courseCircle = $this->makeCourseCircle();
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $routes = [
            route('dashboard'),
            route('institute.edit'),
            route('courses.index'),
            route('shifts.index'),
            route('circles.index'),
            route('circles.show', $courseCircle),
            route('students.index'),
            route('students.create'),
            route('students.show', $student),
            route('students.edit', $student),
            route('teachers.index'),
            route('curricula.index'),
            route('custom-fields.index'),
            route('traits.index'),
        ];

        foreach ($routes as $url) {
            $this->get($url)->assertOk();
        }
    }

    public function test_guests_are_redirected_away_from_the_panel(): void
    {
        auth()->logout();

        $this->get(route('students.index'))->assertRedirect(route('login'));
    }

    public function test_the_institute_form_creates_the_first_institute_when_none_exists(): void
    {
        Institute::query()->forceDelete();
        $this->withSession(['institute_id' => null]);

        Livewire::test('pages::institute.edit')
            ->set('name', 'معهد الفرقان')
            ->set('short_name', 'الفرقان')
            ->set('email', 'info@furqan.test')
            ->call('save')
            ->assertHasNoErrors();

        $this->assertDatabaseHas('institutes', ['name' => 'معهد الفرقان', 'short_name' => 'الفرقان']);
    }

    public function test_a_course_can_be_created_and_made_current(): void
    {
        Livewire::test('pages::courses.index')
            ->call('create')
            ->set('name', 'دورة رمضان 1448')
            ->set('starts_on', '2026-10-01')
            ->set('ends_on', '2026-12-31')
            ->set('status', CourseStatus::Draft->value)
            ->call('save')
            ->assertHasNoErrors();

        $created = Course::query()->where('name', 'دورة رمضان 1448')->sole();

        Livewire::test('pages::courses.index')
            ->call('activate', $created)
            ->assertHasNoErrors();

        $this->assertTrue($created->refresh()->is_current);
        $this->assertFalse($this->course->refresh()->is_current);
    }

    public function test_a_course_cannot_end_before_it_starts(): void
    {
        Livewire::test('pages::courses.index')
            ->call('create')
            ->set('name', 'دورة مقلوبة')
            ->set('starts_on', '2026-10-01')
            ->set('ends_on', '2026-09-01')
            ->call('save')
            ->assertHasErrors(['ends_on']);
    }

    public function test_cloning_from_the_courses_screen_copies_the_previous_structure(): void
    {
        $this->makeCourseCircle('حلقة معاذ بن جبل');

        $next = Course::factory()->create(['institute_id' => $this->institute->id, 'name' => 'الدورة التالية']);

        Livewire::test('pages::courses.index')
            ->call('startClone', $next)
            ->set('cloneSourceId', $this->course->id)
            ->call('cloneStructure')
            ->assertHasNoErrors();

        $this->assertSame(1, $next->courseCircles()->count());
        $this->assertSame(0, $next->courseCircles()->sole()->enrollments()->count());
    }

    public function test_a_shift_stores_its_weekly_days(): void
    {
        Livewire::test('pages::shifts.index')
            ->call('create')
            ->set('name', 'دوام الفجر')
            ->set('starts_at', '05:00')
            ->set('ends_at', '06:30')
            ->set('weekdays', ['1', '3', '5'])
            ->call('save')
            ->assertHasNoErrors();

        $shift = Shift::query()->where('name', 'دوام الفجر')->sole();

        $this->assertSame([1, 3, 5], $shift->weekdays());
        $this->assertSame(['الاثنين', 'الأربعاء', 'الجمعة'], $shift->weekdayLabels());
    }

    public function test_a_shift_needs_at_least_one_weekday(): void
    {
        Livewire::test('pages::shifts.index')
            ->call('create')
            ->set('name', 'دوام بلا أيام')
            ->set('weekdays', [])
            ->call('save')
            ->assertHasErrors(['weekdays']);
    }

    public function test_a_shift_running_circles_cannot_be_deleted(): void
    {
        $this->makeCourseCircle();

        Livewire::test('pages::shifts.index')
            ->call('delete', $this->shift);

        $this->assertNotSoftDeleted($this->shift);
    }

    public function test_a_circle_can_be_created_then_run_in_the_current_course(): void
    {
        Livewire::test('pages::circles.index')
            ->call('create')
            ->set('name', 'حلقة أبي بن كعب')
            ->set('level', 'متقدّم')
            ->call('save')
            ->assertHasNoErrors();

        $circle = Circle::query()->where('name', 'حلقة أبي بن كعب')->sole();

        Livewire::test('pages::circles.index')
            ->call('startRunning', $circle)
            ->set('shift_id', $this->shift->id)
            ->set('room', 'القاعة 3')
            ->set('capacity', '15')
            ->call('run')
            ->assertHasNoErrors();

        $courseCircle = CourseCircle::query()->where('circle_id', $circle->id)->sole();

        $this->assertSame($this->course->id, $courseCircle->course_id);
        $this->assertSame($this->shift->id, $courseCircle->shift_id);
        $this->assertSame(15, $courseCircle->capacity);
    }

    public function test_a_student_is_enrolled_and_then_transferred_from_the_circle_screen(): void
    {
        $from = $this->makeCourseCircle('الحلقة الأولى');
        $to = $this->makeCourseCircle('الحلقة الثانية');
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::circles.show', ['courseCircle' => $from])
            ->set('enrollStudentId', $student->id)
            ->call('enroll')
            ->assertHasNoErrors();

        $this->assertSame(1, $from->activeEnrollments()->count());

        Livewire::test('pages::circles.show', ['courseCircle' => $from])
            ->call('startTransfer', $student)
            ->set('transferTargetId', $to->id)
            ->set('transferReason', 'مستوى أعلى')
            ->call('transfer')
            ->assertHasNoErrors();

        $this->assertSame(0, $from->activeEnrollments()->count());
        $this->assertSame(1, $to->activeEnrollments()->count());

        $transfer = StudentTransfer::query()->sole();
        $this->assertSame($this->admin->id, $transfer->performed_by);
        $this->assertSame('مستوى أعلى', $transfer->reason);
    }

    public function test_enrolling_beyond_capacity_is_refused(): void
    {
        $courseCircle = $this->makeCourseCircle();
        $courseCircle->update(['capacity' => 1]);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => Student::factory()->create(['institute_id' => $this->institute->id])->id,
        ]);

        $extra = Student::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::circles.show', ['courseCircle' => $courseCircle])
            ->set('enrollStudentId', $extra->id)
            ->call('enroll');

        $this->assertSame(1, $courseCircle->activeEnrollments()->count());
    }

    public function test_withdrawing_a_student_keeps_the_enrollment_row(): void
    {
        $courseCircle = $this->makeCourseCircle();
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $enrollment = Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $student->id,
        ]);

        Livewire::test('pages::circles.show', ['courseCircle' => $courseCircle])
            ->call('withdraw', $enrollment);

        $this->assertSame(EnrollmentStatus::Left, $enrollment->refresh()->status);
        $this->assertNotNull($enrollment->left_on);
    }

    public function test_a_teacher_is_created_and_assigned_to_a_circle(): void
    {
        $courseCircle = $this->makeCourseCircle();

        Livewire::test('pages::teachers.index')
            ->call('create')
            ->set('display_name', 'الأستاذ عبد الله')
            ->set('phone', '0955555555')
            ->set('specialization', 'قراءات')
            ->call('save')
            ->assertHasNoErrors();

        $teacher = Teacher::query()->where('display_name', 'الأستاذ عبد الله')->sole();

        Livewire::test('pages::circles.show', ['courseCircle' => $courseCircle])
            ->set('teacherId', $teacher->id)
            ->set('teacherRole', 'main')
            ->call('assignTeacher')
            ->assertHasNoErrors();

        $assignment = CourseCircleTeacher::query()->sole();

        $this->assertSame($teacher->id, $assignment->teacher_id);
        $this->assertNull($assignment->left_on);

        Livewire::test('pages::circles.show', ['courseCircle' => $courseCircle])
            ->call('unassignTeacher', $assignment);

        $this->assertNotNull($assignment->refresh()->left_on);
    }

    public function test_a_custom_field_generates_its_key_from_the_label(): void
    {
        Livewire::test('pages::custom-fields.index')
            ->call('create')
            ->set('label', 'blood type')
            ->set('type', 'select')
            ->set('optionsText', "A+\nO+\n")
            ->set('key', '')
            ->call('save')
            ->assertHasNoErrors();

        $field = CustomField::query()->sole();

        $this->assertSame('blood_type', $field->key);
        $this->assertSame(['A+', 'O+'], $field->options);
        $this->assertSame($this->institute->id, $field->institute_id);
    }

    public function test_an_institute_trait_can_be_added_while_seeded_traits_stay_global(): void
    {
        $global = PersonalTrait::factory()->create(['institute_id' => null, 'name' => 'هادئ']);

        Livewire::test('pages::traits.index')
            ->call('create')
            ->set('name', 'محبّ للمسابقات')
            ->set('polarity', 'positive')
            ->call('save')
            ->assertHasNoErrors();

        $added = PersonalTrait::query()->where('name', 'محبّ للمسابقات')->sole();

        $this->assertSame($this->institute->id, $added->institute_id);
        $this->assertNull($global->refresh()->institute_id);
    }

    public function test_a_curriculum_and_its_items_can_be_managed(): void
    {
        Livewire::test('pages::curricula.index')
            ->call('create')
            ->set('name', 'السيرة النبوية')
            ->set('type', 'custom')
            ->call('save')
            ->assertHasNoErrors();

        $curriculum = Curriculum::query()->where('name', 'السيرة النبوية')->sole();

        Livewire::test('pages::curricula.index')
            ->call('createItem', $curriculum)
            ->set('itemName', 'الهجرة إلى المدينة')
            ->call('saveItem')
            ->assertHasNoErrors();

        $this->assertSame('الهجرة إلى المدينة', $curriculum->items()->sole()->name);
    }

    public function test_the_dashboard_counts_the_current_course_enrollments_only(): void
    {
        $courseCircle = $this->makeCourseCircle();
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $student->id,
        ]);

        $archived = Course::factory()->create(['institute_id' => $this->institute->id]);
        $archivedShift = Shift::factory()->create(['course_id' => $archived->id]);
        $archivedCircle = CourseCircle::factory()->create([
            'course_id' => $archived->id,
            'shift_id' => $archivedShift->id,
        ]);

        Enrollment::factory()->create([
            'course_circle_id' => $archivedCircle->id,
            'student_id' => Student::factory()->create(['institute_id' => $this->institute->id])->id,
        ]);

        Livewire::test('pages::dashboard')
            ->assertSet('institute.id', $this->institute->id)
            ->assertSee($courseCircle->circle->name);

        $counters = Livewire::test('pages::dashboard')->instance()->counters();

        $this->assertSame(1, $counters['enrolled']);
        $this->assertSame(2, $counters['students']);
    }

    public function test_managers_without_an_institute_see_the_setup_prompt(): void
    {
        Institute::query()->forceDelete();

        $this->withSession(['institute_id' => null]);

        $this->get(route('dashboard'))->assertOk()->assertSee('لا يوجد معهد بعد');
    }

    /**
     * من لا معهد مرتبطاً بحسابه لا يُدعى إلى إنشاء معهد — يُخبَر أن حسابه غير مربوط.
     * قبل هذه المرحلة كان السقوط الافتراضي يُدخله «أوّل معهد فعّال» بلا حقّ.
     */
    public function test_users_without_a_linked_institute_are_told_so(): void
    {
        $this->actingAs(User::factory()->create());
        $this->withSession(['institute_id' => null]);

        $this->get(route('dashboard'))->assertOk()->assertSee('حسابك غير مرتبط بمعهد');
    }
}
