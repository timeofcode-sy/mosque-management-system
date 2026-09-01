<?php

namespace Database\Factories;

use App\Enums\Gender;
use App\Enums\StudentStatus;
use App\Models\Institute;
use App\Models\Student;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<Student>
 */
class StudentFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $registeredOn = Carbon::today()->subDays(fake()->numberBetween(30, 900));

        return [
            'institute_id' => Institute::factory(),
            'registration_no' => (string) fake()->unique()->numberBetween(1000, 9999),
            'registration_date' => $registeredOn,
            'registration_date_hijri' => null,
            'first_name' => fake()->randomElement([
                'محمد', 'أحمد', 'عبد الله', 'عمر', 'خالد', 'يوسف', 'إبراهيم',
                'مصطفى', 'بلال', 'أنس', 'زيد', 'حمزة', 'سليمان', 'طارق', 'ياسين',
            ]),
            'father_name' => fake()->randomElement([
                'محمود', 'سامر', 'ماهر', 'عدنان', 'رضوان', 'نبيل', 'فادي', 'زياد', 'حسان',
            ]),
            'family_name' => fake()->randomElement([
                'الأحمد', 'الحسن', 'العلي', 'الخطيب', 'الشامي', 'الحلبي',
                'الدمشقي', 'النجار', 'الحداد', 'السقا', 'القاسم', 'العمر',
            ]),
            'birth_date' => Carbon::today()->subYears(fake()->numberBetween(7, 18))->subDays(fake()->numberBetween(0, 364)),
            'birth_place' => fake()->randomElement(['دمشق', 'حلب', 'حمص', 'حماة', 'دير الزور', 'إدلب']),
            'gender' => Gender::Male,
            'grade_level' => fake()->randomElement([
                'الصف الثالث الابتدائي', 'الصف الرابع الابتدائي', 'الصف الخامس الابتدائي',
                'الصف السادس الابتدائي', 'الصف السابع', 'الصف الثامن', 'الصف التاسع',
                'الأول الثانوي', 'الثاني الثانوي', 'الثالث الثانوي',
            ]),
            'student_job' => fake()->optional(0.2)->randomElement(['يساعد والده في المحل', 'عامل بدوام جزئي', 'بائع']),
            'phone' => fake()->optional(0.5)->numerify('09########'),
            'permanent_address' => fake()->randomElement(['دمشق', 'ريف دمشق', 'حلب']).' - '.fake()->streetName(),
            'current_address' => fake()->streetName().' - بناء رقم '.fake()->numberBetween(1, 60),
            'family_members_count' => fake()->numberBetween(3, 11),
            'student_health_status' => fake()->randomElement(['سليم', 'سليم', 'سليم', 'ضعف في النظر', 'حساسية موسمية', 'ربو خفيف']),
            'family_health_status' => fake()->randomElement(['لا يوجد ما يُذكر', 'لا يوجد ما يُذكر', 'الأب مصاب بالسكري', 'الأم تعاني من ضغط الدم']),
            'status' => StudentStatus::Active,
            'notes' => fake()->optional(0.3)->sentence(),
        ];
    }
}
