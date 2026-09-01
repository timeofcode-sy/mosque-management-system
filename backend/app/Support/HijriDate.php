<?php

namespace App\Support;

use DateTimeInterface;
use IntlDateFormatter;

/**
 * تحويل التاريخ الميلادي إلى الهجري بتقويم أم القرى عبر امتداد intl.
 *
 * الأرقام لاتينية عمداً لتصطفّ مع بقية أرقام النظام (انظر أداة latin-numerals في app.css).
 * حين يغيب intl عن الخادم تعود الدوال بـ null فتُخفي الواجهةُ السطرَ الهجري بدل أن تنهار.
 */
class HijriDate
{
    private const LOCALE = 'ar_SA@calendar=islamic-umalqura;numbers=latn';

    public static function available(): bool
    {
        return extension_loaded('intl');
    }

    /**
     * مثال: 19 ربيع الأول 1448
     */
    public static function long(?DateTimeInterface $date): ?string
    {
        return self::format($date, 'd MMMM yyyy');
    }

    /**
     * مثال: 1448-03-19
     */
    public static function numeric(?DateTimeInterface $date): ?string
    {
        return self::format($date, 'yyyy-MM-dd');
    }

    private static function format(?DateTimeInterface $date, string $pattern): ?string
    {
        if ($date === null || ! self::available()) {
            return null;
        }

        $formatter = new IntlDateFormatter(
            self::LOCALE,
            IntlDateFormatter::NONE,
            IntlDateFormatter::NONE,
            config('app.timezone'),
            IntlDateFormatter::TRADITIONAL,
            $pattern,
        );

        $formatted = $formatter->format($date);

        return $formatted === false ? null : $formatted;
    }
}
