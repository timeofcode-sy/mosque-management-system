<?php

namespace Database\Seeders;

use App\Enums\TraitPolarity;
use App\Models\PersonalTrait;
use Illuminate\Database\Seeder;

/**
 * الصفات الشخصية والسلوكية الواردة في استمارة تسجيل الطالب.
 * تُزرع كصفات عامة (institute_id = null) يرثها كل معهد ويمكنه إضافة غيرها.
 */
class PersonalTraitSeeder extends Seeder
{
    /**
     * @var array<int, array{slug: string, name: string, polarity: TraitPolarity}>
     */
    private const TRAITS = [
        ['slug' => 'calm', 'name' => 'هادئ', 'polarity' => TraitPolarity::Positive],
        ['slug' => 'creative', 'name' => 'مبدع', 'polarity' => TraitPolarity::Positive],
        ['slug' => 'humble', 'name' => 'متواضع', 'polarity' => TraitPolarity::Positive],
        ['slug' => 'hyperactive', 'name' => 'كثير الحركة', 'polarity' => TraitPolarity::Negative],
        ['slug' => 'smart', 'name' => 'ذكي', 'polarity' => TraitPolarity::Positive],
        ['slug' => 'introvert', 'name' => 'انطوائي', 'polarity' => TraitPolarity::Neutral],
        ['slug' => 'sad', 'name' => 'حزين', 'polarity' => TraitPolarity::Negative],
        ['slug' => 'happy', 'name' => 'سعيد', 'polarity' => TraitPolarity::Positive],
        ['slug' => 'shy', 'name' => 'خجول', 'polarity' => TraitPolarity::Neutral],
    ];

    public function run(): void
    {
        foreach (self::TRAITS as $index => $personalTrait) {
            PersonalTrait::query()->updateOrCreate(
                ['institute_id' => null, 'slug' => $personalTrait['slug']],
                [
                    'name' => $personalTrait['name'],
                    'polarity' => $personalTrait['polarity'],
                    'sort_order' => $index,
                    'is_active' => true,
                ],
            );
        }
    }
}
