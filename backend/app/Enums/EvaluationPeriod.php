<?php

namespace App\Enums;

enum EvaluationPeriod: string
{
    case Weekly = 'weekly';
    case Monthly = 'monthly';
    case Term = 'term';

    public function label(): string
    {
        return match ($this) {
            self::Weekly => 'أسبوعي',
            self::Monthly => 'شهري',
            self::Term => 'فصلي',
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
