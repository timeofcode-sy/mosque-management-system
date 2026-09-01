<?php

namespace App\Enums;

enum TraitPolarity: string
{
    case Positive = 'positive';
    case Neutral = 'neutral';
    case Negative = 'negative';

    public function label(): string
    {
        return match ($this) {
            self::Positive => 'صفة إيجابية',
            self::Neutral => 'صفة محايدة',
            self::Negative => 'صفة تحتاج متابعة',
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
