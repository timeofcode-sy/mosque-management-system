<?php

namespace Tests\Feature\Livewire;

use App\Enums\CustomFieldType;
use App\Enums\GuardianRelation;
use App\Models\CustomField;
use App\Models\CustomFieldValue;
use App\Models\Enrollment;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Student;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * بحث الطلاب وتصفيتهم بمعلوماتهم في اللوحة.
 */
class StudentsIndexTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    private function student(string $first, string $father, string $family, array $attributes = []): Student
    {
        return Student::factory()->create([
            'institute_id' => $this->institute->id,
            'first_name' => $first,
            'father_name' => $father,
            'family_name' => $family,
            ...$attributes,
        ]);
    }

    public function test_a_search_without_hamza_finds_the_name_with_it(): void
    {
        $this->student('أحمد', 'محمود', 'سكر');
        $this->student('يوسف', 'خالد', 'الطير');

        Livewire::test('pages::students.index')
            ->set('search', 'احمد سكر')
            ->assertSee('أحمد محمود سكر')
            ->assertDontSee('يوسف خالد الطير')
            ->assertDontSeeHtml('data-test="approximate"');
    }

    public function test_the_closest_names_come_first_and_a_miss_says_it_is_approximate(): void
    {
        $this->student('محمد', 'أسامة', 'عبد العال');
        $this->student('يوسف', 'خالد', 'الطير');

        Livewire::test('pages::students.index')
            ->set('search', 'محمود عبدالعال')
            ->assertSeeHtml('data-test="approximate"')
            ->assertSee('محمد أسامة عبد العال')
            ->assertDontSee('يوسف خالد الطير');
    }

    public function test_students_whose_father_has_died_can_be_listed(): void
    {
        $orphan = $this->student('عدنان', 'محمد فتحي', 'يونس');
        $other = $this->student('زيد', 'عدنان', 'ياسين');

        foreach ([[$orphan, false], [$other, true]] as [$student, $alive]) {
            GuardianStudent::create([
                'guardian_id' => Guardian::factory()->create(['institute_id' => $this->institute->id, 'is_alive' => $alive])->id,
                'student_id' => $student->id,
                'relation' => GuardianRelation::Father,
            ]);
        }

        Livewire::test('pages::students.index')
            ->set('father', 'deceased')
            ->assertSee('عدنان محمد فتحي يونس')
            ->assertDontSee('زيد عدنان ياسين')
            ->assertSee('الأب متوفى');
    }

    public function test_housing_and_address_filter_on_the_student_own_data(): void
    {
        $housing = CustomField::factory()->create([
            'institute_id' => $this->institute->id,
            'entity' => 'student',
            'label' => 'السكن',
            'type' => CustomFieldType::Select,
            'options' => ['ملك', 'أجار'],
        ]);

        $renting = $this->student('هيثم', 'سامر', 'خبية', ['current_address' => 'شارع زملكا مقابل المولدة']);
        $owning = $this->student('بلال', 'محمد', 'الزغلول', ['current_address' => 'العسقلاني']);

        foreach ([[$renting, 'أجار'], [$owning, 'ملك']] as [$student, $value]) {
            CustomFieldValue::create([
                'custom_field_id' => $housing->id,
                'entity_type' => $student->getMorphClass(),
                'entity_id' => $student->id,
                'value' => $value,
            ]);
        }

        Livewire::test('pages::students.index')
            ->set("fields.{$housing->id}", 'اجار')
            ->assertSee('هيثم سامر خبية')
            ->assertDontSee('بلال محمد الزغلول')
            ->call('clearFilters')
            ->set('address', 'زملكا')
            ->assertSee('هيثم سامر خبية')
            ->assertDontSee('بلال محمد الزغلول');
    }

    public function test_students_without_a_circle_can_be_listed_and_filters_removed_one_by_one(): void
    {
        $enrolled = $this->student('سامي', 'أنس', 'حمدان', ['grade_level' => 'رابع']);
        $this->student('عدي', 'عبد اللطيف', 'السقر', ['grade_level' => 'ثاني']);

        Enrollment::create([
            'course_circle_id' => $this->makeCourseCircle()->id,
            'student_id' => $enrolled->id,
            'status' => 'active',
            'enrolled_on' => now()->toDateString(),
        ]);

        Livewire::test('pages::students.index')
            ->set('courseCircleId', 'none')
            ->assertSee('عدي عبد اللطيف السقر')
            ->assertDontSee('سامي أنس حمدان')
            ->set('grade', 'رابع')
            ->assertSee('لا توجد نتائج مطابقة')
            ->call('removeFilter', 'courseCircleId')
            ->assertSee('سامي أنس حمدان')
            ->assertDontSee('عدي عبد اللطيف السقر');
    }
}
