<?php

namespace App\Support;

/**
 * معادلة نسبة الحضور، في مكان واحد.
 *
 * النسبة = (حاضر + متأخّر) ÷ (المجموع − المأذون). الإذن المسبق لا يُحسب غياباً، وإلا
 * عاقب الترتيبُ الحلقةَ على ظرف خارج يدها.
 *
 * كانت هذه المعادلة مكرّرة عمداً في RecalculateCircleStats و DashboardOverviewQuery
 * كي لا يختلف رقم اللوحة عن رقم التقرير؛ وقد صارت ثلاثة مواضع مع StatsQuery، فاستُخرجت.
 */
class AttendanceRate
{
    public static function percent(int $present, int $late, int $excused, int $total, int $precision = 1): float
    {
        $countable = $total - $excused;

        if ($countable <= 0) {
            return 0.0;
        }

        return round(($present + $late) / $countable * 100, $precision);
    }

    /**
     * @param  array{present: int, late: int, excused: int, total: int}  $counts
     */
    public static function of(array $counts, int $precision = 1): float
    {
        return self::percent($counts['present'], $counts['late'], $counts['excused'], $counts['total'], $precision);
    }
}
