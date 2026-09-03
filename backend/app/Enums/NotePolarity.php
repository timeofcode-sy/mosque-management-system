<?php

namespace App\Enums;

/**
 * نوع ملاحظة التفقّد: ثناء أو تنبيه.
 *
 * عليه يقوم مقياس «الأدب» في شاشة الإحصائيات = (الإيجابية) − (السلبية).
 */
enum NotePolarity: string
{
    case Positive = 'positive';
    case Negative = 'negative';

    public function label(): string
    {
        return match ($this) {
            self::Positive => 'ملاحظة إيجابية',
            self::Negative => 'ملاحظة سلبية',
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::Positive => 'green',
            self::Negative => 'red',
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
