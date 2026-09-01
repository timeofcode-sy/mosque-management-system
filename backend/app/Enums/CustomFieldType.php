<?php

namespace App\Enums;

enum CustomFieldType: string
{
    case Text = 'text';
    case Textarea = 'textarea';
    case Number = 'number';
    case Date = 'date';
    case Select = 'select';
    case MultiSelect = 'multi_select';
    case Boolean = 'bool';

    public function label(): string
    {
        return match ($this) {
            self::Text => 'نص قصير',
            self::Textarea => 'نص طويل',
            self::Number => 'رقم',
            self::Date => 'تاريخ',
            self::Select => 'قائمة',
            self::MultiSelect => 'قائمة متعدّدة',
            self::Boolean => 'نعم أو لا',
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
