<?php

namespace Database\Factories;

use App\Models\Circle;
use App\Models\Institute;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Circle>
 */
class CircleFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'institute_id' => Institute::factory(),
            'name' => 'حلقة '.fake()->unique()->randomElement([
                'أبي بن كعب', 'زيد بن ثابت', 'عبد الله بن مسعود', 'أبي موسى الأشعري',
                'معاذ بن جبل', 'سالم مولى أبي حذيفة', 'عثمان بن عفان', 'علي بن أبي طالب',
            ]),
            'level' => fake()->randomElement(['مبتدئ', 'متوسط', 'متقدّم']),
            'color' => fake()->hexColor(),
            'sort_order' => 0,
            'is_active' => true,
        ];
    }
}
