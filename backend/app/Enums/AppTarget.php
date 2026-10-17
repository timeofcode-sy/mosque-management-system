<?php

namespace App\Enums;

/**
 * ما يُحدَّث: كلُّ حالةٍ ملفٌّ واحد يخرج من `scripts/export-apps.ps1` باسمِها نفسِه
 * (`nuzuln-<target>-<version>-b<build>.apk`)، فيُقرأ الهدفُ من اسم الملف عند رفعه.
 *
 * والهدفُ لا التطبيقُ وحده: برنامجُ الإدارة يخرج نسختين (أندرويد وويندوز) لكلٍّ ملفُّها
 * وطريقةُ تثبيتها، فلا يصحّ أن يُعرض ملفُّ ويندوز على هاتف.
 */
enum AppTarget: string
{
    case Mobile = 'mobile';
    case AdminAndroid = 'admin_android';
    case AdminDesktop = 'admin_desktop';

    public function label(): string
    {
        return match ($this) {
            self::Mobile => 'نزلاً · الهاتف',
            self::AdminAndroid => 'الإدارة · أندرويد',
            self::AdminDesktop => 'الإدارة · ويندوز',
        };
    }

    /**
     * من يحمل هذا الهدف — سطرٌ تحت اسمه في شاشة التحديثات.
     */
    public function audience(): string
    {
        return match ($this) {
            self::Mobile => 'الأستاذ وولي الأمر والطالب',
            self::AdminAndroid => 'المشرف ومدير المعهد على الهاتف',
            self::AdminDesktop => 'المشرف ومدير المعهد على الحاسوب',
        };
    }

    public function platform(): string
    {
        return $this === self::AdminDesktop ? 'windows' : 'android';
    }

    /**
     * امتدادُ الملف الذي يُرفع لهذا الهدف: حزمةُ أندرويد، أو مجلّدُ ويندوز مضغوطاً.
     */
    public function extension(): string
    {
        return $this === self::AdminDesktop ? 'zip' : 'apk';
    }

    public function mimeType(): string
    {
        return $this === self::AdminDesktop ? 'application/zip' : 'application/vnd.android.package-archive';
    }

    /**
     * أيقونةُ Flux (heroicons) في بطاقة الهدف.
     */
    public function icon(): string
    {
        return $this === self::AdminDesktop ? 'computer-desktop' : 'device-phone-mobile';
    }

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return collect(self::cases())->mapWithKeys(fn (self $case) => [$case->value => $case->label()])->all();
    }

    /**
     * @return array<int, string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
