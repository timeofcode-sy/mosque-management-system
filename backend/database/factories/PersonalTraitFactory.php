<?php

namespace Database\Factories;

use App\Enums\TraitPolarity;
use App\Models\Institute;
use App\Models\PersonalTrait;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<PersonalTrait>
 */
class PersonalTraitFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $name = fake()->unique()->randomElement(['هادئ', 'مبدع', 'متواضع', 'كثير الحركة', 'ذكي', 'انطوائي', 'حزين', 'سعيد', 'خجول']);

        return [
            'institute_id' => Institute::factory(),
            'name' => $name,
            'slug' => Str::slug($name, '-', 'ar') ?: fake()->unique()->slug(1),
            'polarity' => TraitPolarity::Neutral,
            'sort_order' => 0,
            'is_active' => true,
        ];
    }
}
