<?php

namespace App\Enums;

enum MemorizationType: string
{
    case Hifz = 'hifz';
    case Murajaa = 'murajaa';
    case Tilawah = 'tilawah';

    public function label(): string
    {
        return match ($this) {
            self::Hifz => 'حفظ',
            self::Murajaa => 'مراجعة',
            self::Tilawah => 'تلاوة',
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
