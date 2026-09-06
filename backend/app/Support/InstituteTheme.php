<?php

namespace App\Support;

use App\Models\Institute;

/**
 * هوية المعهد البصرية: ثلاثة ألوان يُدخلها مديرُ المعهد، تُشتقّ منها سلالمُ التدرّج
 * التي تستهلكها اللوحةُ والتقاريرُ والتطبيقاتُ الأربعة.
 *
 * **لماذا ثلاثة لا لوحة كاملة؟** لأن من يُدخلها ليس مصمّماً: شعارُ المعهد يحمل عادةً
 * لوناً أساسياً وثانوياً وأرضيةً فاتحة، وهذه الثلاثة تكفي لبناء كل ما تحتاجه الواجهة.
 * والاشتقاقُ خوارزميٌّ فلا يستطيع أحدٌ أن ينتج تبايناً غيرَ مقروء بخلط عشوائي.
 *
 * **الاشتقاق** — خلطٌ خطّيٌّ في فضاء sRGB نحو الأبيض للفواتح ونحو الأسود للدواكن،
 * بنسبٍ ثابتة (self::BRAND · GOLD · SAND). القيمة المُدخَلة تقع دائماً عند الدرجة
 * الأساسية للسلّم (brand-600 · gold-500 · sand-100) وهي الدرجة التي تستعملها اللوحة
 * أكثر من غيرها.
 *
 * **مصدر الافتراضيات** design/design-tokens.json: معهدٌ لم يضبط ألوانه يبقى على
 * اللوحة الخضراء الذهبية التي بُنيت عليها الواجهة، فالميزةُ إضافةٌ لا فرض.
 *
 * **نظيرُ هذا الصنف في العميل** MousqeTheme في packages/mousqe_ui يطبّق **نفس** النسب
 * على نفس الألوان الثلاثة القادمة في /bootstrap؛ ولذلك تُبثّ الثلاثة لا السلالم:
 * الخوارزمية واحدة موصوفة هنا، والحمولةُ ثلاثةُ حقول لا ثلاثون.
 */
class InstituteTheme
{
    public const DEFAULTS = [
        'primary' => '#0F5132',   // brand-600
        'secondary' => '#C9A227', // gold-500
        'surface' => '#F7F3EA',   // sand-100
    ];

    /**
     * الدرجة => نسبة الخلط. الموجب نحو الأبيض، والسالب نحو الأسود، والصفر هو الأساس.
     *
     * @var array<int, float>
     */
    private const BRAND = [50 => 0.92, 100 => 0.84, 200 => 0.68, 300 => 0.50, 400 => 0.30, 500 => 0.14, 600 => 0.0, 700 => -0.15, 800 => -0.32, 900 => -0.50];

    /** @var array<int, float> */
    private const GOLD = [300 => 0.40, 400 => 0.20, 500 => 0.0, 600 => -0.18, 700 => -0.36];

    /** @var array<int, float> */
    private const SAND = [50 => 0.55, 100 => 0.0, 200 => -0.06, 300 => -0.16];

    /**
     * @param  array{primary: string, secondary: string, surface: string}  $colors
     */
    private function __construct(private readonly array $colors) {}

    public static function for(?Institute $institute): self
    {
        return self::fromArray((array) data_get($institute?->settings, 'theme', []));
    }

    /**
     * @param  array<string, mixed>  $values
     */
    public static function fromArray(array $values): self
    {
        $colors = [];

        foreach (self::DEFAULTS as $key => $default) {
            $colors[$key] = self::normalize($values[$key] ?? null) ?? $default;
        }

        /** @var array{primary: string, secondary: string, surface: string} $colors */
        return new self($colors);
    }

    /**
     * الألوان الثلاثة — ما يُبثّ في /bootstrap وما تُملأ به شاشةُ بيانات المعهد.
     *
     * @return array{primary: string, secondary: string, surface: string}
     */
    public function toArray(): array
    {
        return $this->colors;
    }

    public function isDefault(): bool
    {
        return $this->colors === self::DEFAULTS;
    }

    /**
     * متغيّرات CSS تُحقن بعد ورقة أنماط اللوحة فتغلب قيمَ @theme بترتيب المصدر.
     *
     * تُكتب السلالمُ كلّها لا اللونُ الأساسي وحده، لأن Tailwind يولّد صنفاً لكل درجة
     * (bg-brand-100 · text-gold-700 · border-sand-200) وهي منثورة في الشاشات السبع
     * والعشرين؛ فتركُ الدرجات على قيَمها القديمة كان سيخلط لوحتين في شاشة واحدة.
     */
    public function cssVariables(): string
    {
        $declarations = [];

        foreach (self::BRAND as $step => $ratio) {
            $declarations[] = "--color-brand-{$step}:".self::shade($this->colors['primary'], $ratio);
        }

        foreach (self::GOLD as $step => $ratio) {
            $declarations[] = "--color-gold-{$step}:".self::shade($this->colors['secondary'], $ratio);
        }

        foreach (self::SAND as $step => $ratio) {
            $declarations[] = "--color-sand-{$step}:".self::shade($this->colors['surface'], $ratio);
        }

        return ':root{'.implode(';', $declarations).'}';
    }

    /**
     * لونٌ ممزوجٌ نحو الأبيض (نسبة موجبة) أو نحو الأسود (سالبة).
     */
    public static function shade(string $hex, float $ratio): string
    {
        [$r, $g, $b] = self::rgb($hex);

        $target = $ratio >= 0 ? 255 : 0;
        $weight = abs($ratio);

        $mix = fn (int $channel): int => (int) round($channel + ($target - $channel) * $weight);

        return sprintf('#%02x%02x%02x', $mix($r), $mix($g), $mix($b));
    }

    /**
     * لونٌ سداسيّ صالح بصيغة #rrggbb، أو null لِما لا يصلح — فتسقط القيمة إلى الافتراضي
     * بدل أن تُحقن نصّاً غير آمن في وسم <style>.
     */
    public static function normalize(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $hex = ltrim(trim($value), '#');

        if (preg_match('/^[0-9a-fA-F]{3}$/', $hex) === 1) {
            $hex = $hex[0].$hex[0].$hex[1].$hex[1].$hex[2].$hex[2];
        }

        return preg_match('/^[0-9a-fA-F]{6}$/', $hex) === 1 ? '#'.strtolower($hex) : null;
    }

    /**
     * @return array{int, int, int}
     */
    private static function rgb(string $hex): array
    {
        $hex = ltrim($hex, '#');

        return [
            (int) hexdec(substr($hex, 0, 2)),
            (int) hexdec(substr($hex, 2, 2)),
            (int) hexdec(substr($hex, 4, 2)),
        ];
    }
}
