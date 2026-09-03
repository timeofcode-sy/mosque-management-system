<?php

namespace App\Enums;

/**
 * سبب منح النقاط التقديرية — ما يمنحه الأستاذ بيده خارج الحساب الآلي.
 */
enum PointReason: string
{
    case Behavior = 'behavior';
    case Participation = 'participation';
    case Competition = 'competition';
    case Reward = 'reward';
    case Excellence = 'excellence';
    case Volunteering = 'volunteering';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Behavior => 'سلوك',
            self::Participation => 'مشاركة',
            self::Competition => 'مسابقة',
            self::Reward => 'مكافأة',
            self::Excellence => 'أداء مميّز',
            self::Volunteering => 'تطوّع',
            self::Other => 'أخرى',
        };
    }

    /**
     * اتّجاه السبب المعتاد — تلوّن به الواجهة الحقل وتقترح إشارة القيمة.
     *
     * السلوك وحده ذو وجهين (أدبٌ يُثاب عليه ومشاغبةٌ تُخصم)، فيبقى «كلاهما».
     */
    public function polarity(): TraitPolarity
    {
        return match ($this) {
            self::Behavior, self::Other => TraitPolarity::Neutral,
            default => TraitPolarity::Positive,
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
