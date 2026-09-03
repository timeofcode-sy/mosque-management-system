<?php

namespace App\Enums;

/**
 * تقدير التسميع — يضرب نقاط المدى بمعامل قابل للضبط في إعدادات المعهد.
 */
enum RecitationGrade: string
{
    case Excellent = 'excellent';
    case VeryGood = 'very_good';
    case Good = 'good';

    public function label(): string
    {
        return match ($this) {
            self::Excellent => 'ممتاز',
            self::VeryGood => 'جيد جداً',
            self::Good => 'جيد',
        };
    }

    /**
     * لون شارة التقدير في اللوحة.
     */
    public function color(): string
    {
        return match ($this) {
            self::Excellent => 'green',
            self::VeryGood => 'amber',
            self::Good => 'zinc',
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
