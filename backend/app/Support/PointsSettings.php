<?php

namespace App\Support;

use App\Enums\AttendanceStatus;
use App\Enums\CurriculumType;
use App\Enums\RecitationGrade;
use App\Models\CurriculumItem;
use App\Models\Institute;

/**
 * إعدادات النقاط لمعهد، مقروءة من institutes.settings['points'] بقيم افتراضية.
 *
 * الغلاف يمنع تناثر data_get($institute->settings, 'points.…') في الإجراءات والشاشات،
 * ويجعل تغيير شكل الإعدادات مسألة ملف واحد.
 */
class PointsSettings
{
    /**
     * القيم الافتراضية — تُستعمل حين لا يضبط المعهد شيئاً، وتُملأ بها شاشة الإعدادات.
     *
     * @var array<string, mixed>
     */
    public const DEFAULTS = [
        'quran_per_15_lines' => 10,
        'hadith_per_item' => 5,
        'mutun_per_bayt' => 1,
        'attendance' => ['present' => 2, 'late' => 1, 'excused' => 0, 'absent' => 0],
        'grade_multiplier' => ['excellent' => 100, 'very_good' => 80, 'good' => 60],
    ];

    /**
     * @param  array<string, mixed>  $values
     */
    private function __construct(private readonly array $values) {}

    public static function for(?Institute $institute): self
    {
        return new self((array) data_get($institute?->settings, 'points', []));
    }

    /**
     * @param  array<string, mixed>  $values
     */
    public static function fromArray(array $values): self
    {
        return new self($values);
    }

    public function quranPer15Lines(): float
    {
        return (float) $this->value('quran_per_15_lines');
    }

    public function hadithPerItem(): float
    {
        return (float) $this->value('hadith_per_item');
    }

    public function mutunPerBayt(): float
    {
        return (float) $this->value('mutun_per_bayt');
    }

    public function attendance(AttendanceStatus $status): float
    {
        return (float) $this->value("attendance.{$status->value}");
    }

    /**
     * معامل التقدير كنسبة من الواحد: «جيد جداً» المخزَّن 80 يعود 0.80.
     */
    public function gradeMultiplier(?RecitationGrade $grade): float
    {
        if ($grade === null) {
            return 1.0;
        }

        return (float) $this->value("grade_multiplier.{$grade->value}") / 100;
    }

    /**
     * نقاط مدى قرآني من أسطره الجديدة — الصيغة الوحيدة في النظام.
     */
    public function quranPoints(float $newLines, ?RecitationGrade $grade): float
    {
        return round($newLines / 15 * $this->quranPer15Lines() * $this->gradeMultiplier($grade), 2);
    }

    /**
     * نقاط إنجاز بند منهج: النسبة × عدّاد البند × معامل النوع.
     *
     * البند بلا عدّاد (بند مخصّص، أو جزء قرآني) يُحسب وحدةً واحدة، فلا يضيع إنجازه
     * لمجرّد أن المشرف لم يملأ عدّاداً.
     */
    public function progressPoints(CurriculumItem $item, int $percent): float
    {
        $type = $item->curriculum?->type;

        [$count, $factor] = match ($type) {
            CurriculumType::Hadith => [(int) ($item->meta['hadiths'] ?? 1), $this->hadithPerItem()],
            CurriculumType::Mutun => [(int) ($item->meta['abyat'] ?? 1), $this->mutunPerBayt()],
            default => [0, 0.0],
        };

        return round($percent / 100 * max(1, $count) * $factor, 2);
    }

    /**
     * الإعدادات كاملةً بعد دمجها بالافتراضيات — تعبّئ بها شاشة المعهد حقولها.
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'quran_per_15_lines' => $this->quranPer15Lines(),
            'hadith_per_item' => $this->hadithPerItem(),
            'mutun_per_bayt' => $this->mutunPerBayt(),
            'attendance' => collect(AttendanceStatus::cases())
                ->mapWithKeys(fn (AttendanceStatus $status) => [$status->value => $this->attendance($status)])
                ->all(),
            'grade_multiplier' => collect(RecitationGrade::cases())
                ->mapWithKeys(fn (RecitationGrade $grade) => [$grade->value => $this->gradeMultiplier($grade) * 100])
                ->all(),
        ];
    }

    private function value(string $key): mixed
    {
        return data_get($this->values, $key) ?? data_get(self::DEFAULTS, $key);
    }
}
