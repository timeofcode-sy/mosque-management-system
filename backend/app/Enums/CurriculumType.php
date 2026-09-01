<?php

namespace App\Enums;

enum CurriculumType: string
{
    case Quran = 'quran';
    case Hadith = 'hadith';
    case Mutun = 'mutun';
    case Custom = 'custom';

    public function label(): string
    {
        return match ($this) {
            self::Quran => 'القرآن الكريم',
            self::Hadith => 'الحديث الشريف',
            self::Mutun => 'المتون العلمية',
            self::Custom => 'منهج مخصّص',
        };
    }

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return collect(self::cases())->mapWithKeys(fn (self $case) => [$case->value => $case->label()])->all();
    }
}
