<?php

namespace App\Enums;

enum TeacherRole: string
{
    case Main = 'main';
    case Assistant = 'assistant';

    public function label(): string
    {
        return match ($this) {
            self::Main => 'أستاذ أساسي',
            self::Assistant => 'أستاذ مساعد',
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
