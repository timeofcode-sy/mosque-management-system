<?php

namespace App\Support;

use App\Models\Course;
use Illuminate\Support\Carbon;

/**
 * مدى تواريخ مسمّى: الأسبوع، الشهر، الدورة كاملةً، أو مدى مخصّص.
 *
 * تستعمله شاشتا التقارير والإحصائيات معاً، فيبقى معنى «الأسبوع» واحداً في الشاشتين.
 */
class DateRange
{
    public const WEEK = 'week';

    public const MONTH = 'month';

    public const COURSE = 'course';

    public const CUSTOM = 'custom';

    private function __construct(
        public readonly string $from,
        public readonly string $to,
        public readonly string $key,
    ) {}

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return [
            self::WEEK => 'الأسبوع',
            self::MONTH => 'الشهر',
            self::COURSE => 'الدورة كاملة',
            self::CUSTOM => 'مدى مخصّص',
        ];
    }

    public static function make(string $key, ?Course $course = null, ?string $from = null, ?string $to = null, ?string $anchor = null): self
    {
        $end = Carbon::parse($anchor ?? Carbon::today());

        return match ($key) {
            self::MONTH => new self($end->copy()->subDays(29)->toDateString(), $end->toDateString(), self::MONTH),
            self::COURSE => new self(
                $course?->starts_on?->toDateString() ?? $end->copy()->subMonths(6)->toDateString(),
                $course?->ends_on?->toDateString() ?? $end->toDateString(),
                self::COURSE,
            ),
            self::CUSTOM => new self(
                $from ?: $end->copy()->subDays(6)->toDateString(),
                $to ?: $end->toDateString(),
                self::CUSTOM,
            ),
            default => new self($end->copy()->subDays(6)->toDateString(), $end->toDateString(), self::WEEK),
        };
    }

    public function label(): string
    {
        return self::options()[$this->key] ?? $this->key;
    }
}
