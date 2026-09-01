<?php

namespace App\Enums;

enum EnrollmentStatus: string
{
    case Active = 'active';
    case Left = 'left';
    case Transferred = 'transferred';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'مسجَّل',
            self::Left => 'منسحب',
            self::Transferred => 'منقول',
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
