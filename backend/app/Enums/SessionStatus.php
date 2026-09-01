<?php

namespace App\Enums;

enum SessionStatus: string
{
    case Draft = 'draft';
    case Completed = 'completed';
    case Locked = 'locked';

    public function label(): string
    {
        return match ($this) {
            self::Draft => 'مسودّة',
            self::Completed => 'مكتملة',
            self::Locked => 'مقفلة',
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
