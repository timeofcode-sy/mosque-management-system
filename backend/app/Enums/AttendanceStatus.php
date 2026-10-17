<?php

namespace App\Enums;

enum AttendanceStatus: string
{
    case Present = 'present';
    case Absent = 'absent';
    case Late = 'late';
    case Excused = 'excused';

    public function label(): string
    {
        return match ($this) {
            self::Present => 'حاضر',
            self::Absent => 'غائب',
            self::Late => 'متأخّر',
            self::Excused => 'غائب بعذر',
        };
    }

    /**
     * غائبٌ بعذرٍ أو بغيره: لم يحضر الجلسة، فلا ملاحظةَ عليه فيها ولا نقاطَ ولا تسميع.
     */
    public function isAbsence(): bool
    {
        return $this === self::Absent || $this === self::Excused;
    }

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return collect(self::cases())->mapWithKeys(fn (self $case) => [$case->value => $case->label()])->all();
    }
}
