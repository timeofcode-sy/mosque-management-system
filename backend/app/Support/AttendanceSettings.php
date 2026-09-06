<?php

namespace App\Support;

use App\Models\Institute;

/**
 * إعدادات التفقّد لمعهد، مقروءة من institutes.settings['attendance'] بقيم افتراضية.
 *
 * نظير PointsSettings ومفصولٌ عنه عمداً: مفتاح settings واحد لكل موضوع، فتعديلُ
 * إعدادات النقاط لا يمسّ إعدادات التفقّد ولا العكس.
 */
class AttendanceSettings
{
    /**
     * فترة السماح صفرٌ افتراضاً، فيكون «دقائق التأخير» حرفياً كم دقيقة بعد بداية
     * الدوام — وهو أقلّ المعاني مفاجأةً. ومعهدٌ يريد تسامحاً يضبطها بنفسه.
     *
     * @var array<string, mixed>
     */
    public const DEFAULTS = [
        'late_grace_minutes' => 0,
    ];

    /**
     * @param  array<string, mixed>  $values
     */
    private function __construct(private readonly array $values) {}

    public static function for(?Institute $institute): self
    {
        return new self((array) data_get($institute?->settings, 'attendance', []));
    }

    public function lateGraceMinutes(): int
    {
        return max(0, (int) ($this->values['late_grace_minutes'] ?? self::DEFAULTS['late_grace_minutes']));
    }

    /**
     * الإعدادات كاملةً بعد دمجها بالافتراضيات — تعبّئ بها شاشة المعهد حقولها.
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return ['late_grace_minutes' => $this->lateGraceMinutes()];
    }
}
