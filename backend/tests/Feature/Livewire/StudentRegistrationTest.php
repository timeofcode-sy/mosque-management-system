<?php

namespace Tests\Feature\Livewire;

use App\Enums\EnrollmentStatus;
use App\Enums\GuardianRelation;
use App\Enums\ProgressStatus;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\CustomField;
use App\Models\Enrollment;
use App\Models\PersonalTrait;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class StudentRegistrationTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_the_registration_form_stores_every_section_of_the_paper_form(): void
    {
        $courseCircle = $this->makeCourseCircle('حلقة زيد بن ثابت');

        $calm = PersonalTrait::factory()->create(['institute_id' => null, 'name' => 'هادئ']);
        $shy = PersonalTrait::factory()->create(['institute_id' => null, 'name' => 'خجول']);

        $curriculum = Curriculum::factory()->create(['institute_id' => null, 'name' => 'القرآن الكريم']);
        $firstJuz = CurriculumItem::factory()->create(['curriculum_id' => $curriculum->id, 'name' => 'الجزء الأول']);

        $bloodType = CustomField::factory()->create([
            'institute_id' => $this->institute->id,
            'entity' => 'student',
            'key' => 'blood_type',
            'label' => 'زمرة الدم',
        ]);

        Livewire::test('pages::students.form')
            ->set('registration_no', 'A-104')
            ->set('registration_date', '2026-09-01')
            ->set('registration_date_hijri', '1448/03/12')
            ->set('first_name', 'عبد الرحمن')
            ->set('father_name', 'سامر')
            ->set('family_name', 'الخطيب')
            ->set('birth_date', '2014-05-11')
            ->set('birth_place', 'دمشق')
            ->set('grade_level', 'الصف السادس الابتدائي')
            ->set('student_job', 'يساعد والده في المحل')
            ->set('phone', '0912345678')
            ->set('permanent_address', 'دمشق - الميدان')
            ->set('current_address', 'دمشق - المزة')
            ->set('father_full_name', 'سامر الخطيب')
            ->set('father_occupation', 'نجّار')
            ->set('father_phone', '0911111111')
            ->set('mother_full_name', 'أم عبد الرحمن')
            ->set('mother_occupation', 'ربّة منزل')
            ->set('mother_phone', '0922222222')
            ->set('family_members_count', '6')
            ->set('student_health_status', 'ضعف في النظر')
            ->set('family_health_status', 'الأب مصاب بالسكري')
            ->set('traitIds', [(string) $calm->id, (string) $shy->id])
            ->set('memorizedItemIds', [(string) $firstJuz->id])
            ->set('customFields', [$bloodType->id => 'O+'])
            ->set('courseCircleId', $courseCircle->id)
            ->set('notes', 'طالب مجتهد')
            ->call('save')
            ->assertHasNoErrors();

        $student = Student::query()->where('registration_no', 'A-104')->sole();

        $this->assertSame('عبد الرحمن سامر الخطيب', $student->full_name);
        $this->assertSame('1448/03/12', $student->registration_date_hijri);
        $this->assertSame(6, $student->family_members_count);
        $this->assertSame('ضعف في النظر', $student->student_health_status);
        $this->assertSame($this->institute->id, $student->institute_id);

        $this->assertSame('سامر الخطيب', $student->father()?->full_name);
        $this->assertSame('نجّار', $student->father()?->occupation);
        $this->assertSame('أم عبد الرحمن', $student->mother()?->full_name);
        $this->assertSame(
            GuardianRelation::Father->value,
            $student->guardians->firstWhere('full_name', 'سامر الخطيب')->pivot->relation,
        );

        $this->assertEqualsCanonicalizing(
            [$calm->id, $shy->id],
            $student->personalTraits->pluck('id')->all(),
        );

        $progress = StudentCurriculumProgress::query()->where('student_id', $student->id)->sole();
        $this->assertSame($firstJuz->id, $progress->curriculum_item_id);
        $this->assertSame(ProgressStatus::Memorized, $progress->status);

        $this->assertSame('O+', $student->customFieldValues()->sole()->value);

        $enrollment = $student->enrollments()->sole();
        $this->assertSame($courseCircle->id, $enrollment->course_circle_id);
        $this->assertSame(EnrollmentStatus::Active, $enrollment->status);
    }

    public function test_the_form_rejects_a_duplicate_registration_number_within_the_institute(): void
    {
        Student::factory()->create(['institute_id' => $this->institute->id, 'registration_no' => 'A-1']);

        Livewire::test('pages::students.form')
            ->set('registration_no', 'A-1')
            ->set('first_name', 'محمد')
            ->set('father_name', 'أحمد')
            ->set('family_name', 'العلي')
            ->call('save')
            ->assertHasErrors(['registration_no' => 'unique']);
    }

    public function test_the_three_part_name_is_required(): void
    {
        Livewire::test('pages::students.form')
            ->set('first_name', '')
            ->call('save')
            ->assertHasErrors(['first_name', 'father_name', 'family_name']);
    }

    public function test_editing_loads_the_stored_form_and_updates_it(): void
    {
        $student = Student::factory()->create([
            'institute_id' => $this->institute->id,
            'first_name' => 'أنس',
            'grade_level' => 'الصف السابع',
        ]);

        Livewire::test('pages::students.form', ['student' => $student])
            ->assertSet('first_name', 'أنس')
            ->assertSet('grade_level', 'الصف السابع')
            ->set('grade_level', 'الصف الثامن')
            ->call('save')
            ->assertHasNoErrors();

        $this->assertSame('الصف الثامن', $student->refresh()->grade_level);
        $this->assertSame(1, Student::query()->where('institute_id', $this->institute->id)->count());
    }

    public function test_unselecting_a_memorized_item_resets_it_without_losing_the_row(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $curriculum = Curriculum::factory()->create(['institute_id' => null]);
        $item = CurriculumItem::factory()->create(['curriculum_id' => $curriculum->id]);

        StudentCurriculumProgress::create([
            'student_id' => $student->id,
            'curriculum_item_id' => $item->id,
            'status' => ProgressStatus::Memorized,
            'notes' => 'أتمّه في رمضان',
        ]);

        Livewire::test('pages::students.form', ['student' => $student])
            ->assertSet('memorizedItemIds', [(string) $item->id])
            ->set('memorizedItemIds', [])
            ->call('save')
            ->assertHasNoErrors();

        $progress = StudentCurriculumProgress::query()->where('student_id', $student->id)->sole();

        $this->assertSame(ProgressStatus::NotStarted, $progress->status);
        $this->assertSame('أتمّه في رمضان', $progress->notes);
    }

    public function test_the_index_filters_students_by_search_and_circle(): void
    {
        $courseCircle = $this->makeCourseCircle();

        $enrolled = Student::factory()->create(['institute_id' => $this->institute->id, 'first_name' => 'بلال']);
        $other = Student::factory()->create(['institute_id' => $this->institute->id, 'first_name' => 'حمزة']);

        Enrollment::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'student_id' => $enrolled->id,
        ]);

        Livewire::test('pages::students.index')
            ->set('search', 'بلال')
            ->assertSee('بلال')
            ->assertDontSee('حمزة')
            ->set('search', '')
            ->set('courseCircleId', (string) $courseCircle->id)
            ->assertSee($enrolled->full_name)
            ->assertDontSee($other->full_name);
    }
}
