<?php

namespace App\Enums;

enum ReportScope: string
{
    case Circle = 'circle';
    case Shift = 'shift';
    case Course = 'course';
    case Institute = 'institute';

    public function label(): string
    {
        return match ($this) {
            self::Circle => 'الحلقة',
            self::Shift => 'الدوام',
            self::Course => 'الدورة',
            self::Institute => 'المعهد',
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
