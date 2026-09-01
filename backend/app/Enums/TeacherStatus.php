<?php

namespace App\Enums;

enum TeacherStatus: string
{
    case Active = 'active';
    case Suspended = 'suspended';
    case Left = 'left';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'على رأس العمل',
            self::Suspended => 'موقوف',
            self::Left => 'منتهي الخدمة',
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
