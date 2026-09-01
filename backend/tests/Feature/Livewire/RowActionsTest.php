<?php

namespace Tests\Feature\Livewire;

use App\Models\Circle;
use App\Models\CourseCircleTeacher;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\CustomField;
use App\Models\Enrollment;
use App\Models\PersonalTrait;
use App\Models\Shift;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * أزرار الصفوف (تعديل/حذف/…) تمرّر مفتاح المسار — وهو `uuid` بحكم App\Concerns\HasUuid —
 * لا المفتاح الأساسي. تمرير `id` كان يرفع ModelNotFoundException فيردّ Livewire بـ 404
 * تعرضه الواجهة في نافذة بدل فتح النافذة المنبثقة. هذه الاختبارات تحرس ذلك.
 */
class RowActionsTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_course_row_actions_resolve_by_route_key(): void
    {
        Livewire::test('pages::courses.index')
            ->call('edit', $this->course->getRouteKey())
            ->assertSet('name', $this->course->name)
            ->call('startClone', $this->course->getRouteKey())
            ->assertHasNoErrors();
    }

    public function test_shift_row_actions_resolve_by_route_key(): void
    {
        $shift = Shift::factory()->create(['course_id' => $this->course->id]);

        Livewire::test('pages::shifts.index')
            ->call('edit', $shift->getRouteKey())
            ->assertSet('name', $shift->name)
            ->call('delete', $shift->getRouteKey());

        $this->assertSoftDeleted($shift);
    }

    public function test_circle_row_actions_resolve_by_route_key(): void
    {
        $circle = Circle::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::circles.index')
            ->call('edit', $circle->getRouteKey())
            ->assertSet('name', $circle->name)
            ->call('startRunning', $circle->getRouteKey())
            ->assertSet('runningCircleId', $circle->id);
    }

    public function test_teacher_row_actions_resolve_by_route_key(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::teachers.index')
            ->call('edit', $teacher->getRouteKey())
            ->assertSet('display_name', $teacher->display_name)
            ->call('delete', $teacher->getRouteKey());

        $this->assertSoftDeleted($teacher);
    }

    public function test_student_delete_resolves_by_route_key(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::students.index')
            ->call('delete', $student->getRouteKey());

        $this->assertSoftDeleted($student);
    }

    public function test_curriculum_row_actions_resolve_by_route_key(): void
    {
        $curriculum = Curriculum::factory()->create(['institute_id' => $this->institute->id]);
        $item = CurriculumItem::factory()->create(['curriculum_id' => $curriculum->id]);

        Livewire::test('pages::curricula.index')
            ->call('edit', $curriculum->getRouteKey())
            ->assertSet('name', $curriculum->name)
            ->call('createItem', $curriculum->getRouteKey())
            ->assertSet('itemCurriculumId', $curriculum->id)
            ->call('editItem', $item->getRouteKey())
            ->assertSet('itemName', $item->name)
            ->call('deleteItem', $item->getRouteKey());

        $this->assertModelMissing($item);
    }

    public function test_custom_field_row_actions_resolve_by_route_key(): void
    {
        $field = CustomField::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::custom-fields.index')
            ->call('edit', $field->getRouteKey())
            ->assertSet('label', $field->label)
            ->call('delete', $field->getRouteKey());

        $this->assertSoftDeleted($field);
    }

    public function test_trait_row_actions_resolve_by_route_key(): void
    {
        $personalTrait = PersonalTrait::factory()->create(['institute_id' => $this->institute->id]);

        Livewire::test('pages::traits.index')
            ->call('edit', $personalTrait->getRouteKey())
            ->assertSet('name', $personalTrait->name)
            ->call('delete', $personalTrait->getRouteKey());

        $this->assertModelMissing($personalTrait);
    }

    public function test_circle_show_row_actions_resolve_by_route_key(): void
    {
        $courseCircle = $this->makeCourseCircle();
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $enrollment = Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $student->id,
        ]);
        $assignment = CourseCircleTeacher::factory()->create([
            'course_circle_id' => $courseCircle->id,
        ]);

        Livewire::test('pages::circles.show', ['courseCircle' => $courseCircle])
            ->call('startTransfer', $student->getRouteKey())
            ->assertSet('transferringStudentId', $student->id)
            ->call('unassignTeacher', $assignment->getRouteKey())
            ->call('withdraw', $enrollment->getRouteKey());

        $this->assertSame('left', $enrollment->fresh()->status->value);
    }
}
