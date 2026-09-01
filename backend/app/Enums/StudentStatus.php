<?php

namespace App\Enums;

enum StudentStatus: string
{
    case Active = 'active';
    case Suspended = 'suspended';
    case Graduated = 'graduated';
    case Withdrawn = 'withdrawn';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'منتظم',
            self::Suspended => 'موقوف',
            self::Graduated => 'متخرّج',
            self::Withdrawn => 'منسحب',
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
