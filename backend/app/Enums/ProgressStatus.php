<?php

namespace App\Enums;

enum ProgressStatus: string
{
    case NotStarted = 'not_started';
    case InProgress = 'in_progress';
    case Memorized = 'memorized';
    case Mastered = 'mastered';

    public function label(): string
    {
        return match ($this) {
            self::NotStarted => 'لم يبدأ',
            self::InProgress => 'قيد الحفظ',
            self::Memorized => 'محفوظ',
            self::Mastered => 'متقَن',
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
