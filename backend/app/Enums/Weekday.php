<?php

namespace App\Enums;

/**
 * أيام الأسبوع بترقيم Carbon::dayOfWeek (0 = الأحد) — نفس ما يُخزَّن في shift_days.weekday.
 */
enum Weekday: int
{
    case Sunday = 0;
    case Monday = 1;
    case Tuesday = 2;
    case Wednesday = 3;
    case Thursday = 4;
    case Friday = 5;
    case Saturday = 6;

    public function label(): string
    {
        return match ($this) {
            self::Sunday => 'الأحد',
            self::Monday => 'الاثنين',
            self::Tuesday => 'الثلاثاء',
            self::Wednesday => 'الأربعاء',
            self::Thursday => 'الخميس',
            self::Friday => 'الجمعة',
            self::Saturday => 'السبت',
        };
    }

    /**
     * @return array<int, string>
     */
    public static function options(): array
    {
        return collect(self::cases())->mapWithKeys(fn (self $case) => [$case->value => $case->label()])->all();
    }
}
