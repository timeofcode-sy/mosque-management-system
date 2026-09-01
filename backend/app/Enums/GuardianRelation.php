<?php

namespace App\Enums;

enum GuardianRelation: string
{
    case Father = 'father';
    case Mother = 'mother';
    case Brother = 'brother';
    case Uncle = 'uncle';
    case Grandfather = 'grandfather';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Father => 'الأب',
            self::Mother => 'الأم',
            self::Brother => 'الأخ',
            self::Uncle => 'العم أو الخال',
            self::Grandfather => 'الجد',
            self::Other => 'صلة أخرى',
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
