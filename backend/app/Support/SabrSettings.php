<?php

namespace App\Support;

use App\Models\Institute;

/**
 * إعدادات سبر الأجزاء لمعهد، مقروءة من institutes.settings['sabr'] بقيم افتراضية.
 *
 * السبر اختبار الأستاذ للطالب في نهاية تسميع الجزء، بعلامة من مئة. والنجاح يُقاس
 * بعلامة المعهد الحالية لا بعلامة يوم السبر: تعديلها يعيد الحكم على ما مضى، وهو
 * المقصود من تعديلها.
 */
class SabrSettings
{
    /**
     * @var array<string, mixed>
     */
    public const DEFAULTS = [
        'pass_mark' => 80,
    ];

    /**
     * @param  array<string, mixed>  $values
     */
    private function __construct(private readonly array $values) {}

    public static function for(?Institute $institute): self
    {
        return new self((array) data_get($institute?->settings, 'sabr', []));
    }

    public function passMark(): int
    {
        return min(100, max(0, (int) ($this->values['pass_mark'] ?? self::DEFAULTS['pass_mark'])));
    }

    /**
     * حكم السبر: null حين لم يُسبر الجزء بعد.
     */
    public function passed(?int $score): ?bool
    {
        return $score === null ? null : $score >= $this->passMark();
    }

    /**
     * الإعدادات كاملةً بعد دمجها بالافتراضيات — تعبّئ بها شاشة المعهد حقولها.
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return ['pass_mark' => $this->passMark()];
    }
}
