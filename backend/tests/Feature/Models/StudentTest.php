<?php

namespace Tests\Feature\Models;

use App\Enums\GuardianRelation;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Student;
use App\Models\StudentTrait;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class StudentTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_student_gets_a_uuid_on_creation(): void
    {
        $student = Student::factory()->create();

        $this->assertTrue(Str::isUuid($student->uuid));
    }

    public function test_the_full_name_joins_the_three_name_parts(): void
    {
        $student = Student::factory()->create([
            'first_name' => 'إبراهيم',
            'father_name' => 'نبيل',
            'family_name' => 'الدمشقي',
        ]);

        $this->assertSame('إبراهيم نبيل الدمشقي', $student->full_name);
    }

    public function test_it_stores_the_registration_form_fields(): void
    {
        $student = Student::factory()->create([
            'registration_no' => '1024',
            'grade_level' => 'الصف السابع',
            'birth_place' => 'حماة',
            'student_job' => 'يساعد والده في المحل',
            'permanent_address' => 'دمشق - الميدان',
            'current_address' => 'دمشق - المزة',
            'family_members_count' => 6,
            'student_health_status' => 'ضعف في النظر',
            'family_health_status' => 'الأب مصاب بالسكري',
        ]);

        $this->assertDatabaseHas('students', [
            'id' => $student->id,
            'registration_no' => '1024',
            'grade_level' => 'الصف السابع',
            'family_members_count' => 6,
            'student_health_status' => 'ضعف في النظر',
        ]);
    }

    public function test_it_resolves_the_father_and_the_mother_from_the_guardians(): void
    {
        $institute = Institute::factory()->create();
        $student = Student::factory()->create(['institute_id' => $institute->id]);

        $father = Guardian::factory()->create(['institute_id' => $institute->id, 'occupation' => 'تاجر']);
        $mother = Guardian::factory()->mother()->create(['institute_id' => $institute->id, 'occupation' => 'معلمة']);

        GuardianStudent::create([
            'guardian_id' => $father->id,
            'student_id' => $student->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
        ]);

        GuardianStudent::create([
            'guardian_id' => $mother->id,
            'student_id' => $student->id,
            'relation' => GuardianRelation::Mother,
        ]);

        $student->load('guardians');

        $this->assertSame($father->id, $student->father()?->id);
        $this->assertSame('تاجر', $student->father()?->occupation);
        $this->assertSame($mother->id, $student->mother()?->id);
        $this->assertSame('معلمة', $student->mother()?->occupation);
    }

    public function test_a_student_can_carry_several_personal_traits(): void
    {
        $student = Student::factory()->create();
        $traits = PersonalTrait::factory()->count(3)->create(['institute_id' => null]);

        foreach ($traits as $personalTrait) {
            StudentTrait::create(['student_id' => $student->id, 'trait_id' => $personalTrait->id]);
        }

        $this->assertCount(3, $student->personalTraits()->get());
    }

    public function test_the_same_trait_cannot_be_assigned_twice(): void
    {
        $student = Student::factory()->create();
        $personalTrait = PersonalTrait::factory()->create(['institute_id' => null]);

        StudentTrait::create(['student_id' => $student->id, 'trait_id' => $personalTrait->id]);

        $this->expectException(UniqueConstraintViolationException::class);

        StudentTrait::create(['student_id' => $student->id, 'trait_id' => $personalTrait->id]);
    }
}
