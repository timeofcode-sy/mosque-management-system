<?php

namespace App\Enums;

/**
 * أدوار اللوحة مرتّبةً هرمياً — المصدر الوحيد لأسماء الأدوار وتسمياتها العربية،
 * تقرأ منه البذرةُ وشاشةُ المستخدمين وإجراءاتُ الإسناد معاً.
 *
 * ترتيب الحالات هو الهرم نفسه: الأعلى أوّلاً. عليه تقوم قاعدة «لا يُسند دورٌ أعلى
 * من دور المُسنِد» في AssignUserRole.
 */
enum PanelRole: string
{
    case Developer = 'developer';
    case SuperAdmin = 'super_admin';
    case Admin = 'admin';
    case Supervisor = 'supervisor';
    case Teacher = 'teacher';
    case Guardian = 'guardian';
    case Student = 'student';

    public function label(): string
    {
        return match ($this) {
            self::Developer => 'مبرمج',
            self::SuperAdmin => 'المشرف الأعلى',
            self::Admin => 'مدير معهد',
            self::Supervisor => 'مشرف',
            self::Teacher => 'أستاذ',
            self::Guardian => 'ولي أمر',
            self::Student => 'طالب',
        };
    }

    /**
     * الدور العابر للمعاهد يُسنَد خارج كل معهد (User::GLOBAL_TEAM_ID) لا داخل واحد.
     */
    public function isGlobal(): bool
    {
        return $this === self::Developer || $this === self::SuperAdmin;
    }

    /**
     * رتبة الدور في الهرم — الأصغر أعلى.
     */
    public function rank(): int
    {
        return (int) array_search($this, self::cases(), true);
    }

    /**
     * بادئة اسم المستخدم المولَّد لهذا الدور — مع رقمٍ متسلسل تصير student2395.
     */
    public function usernamePrefix(): string
    {
        return match ($this) {
            self::Developer => 'dev',
            self::SuperAdmin => 'sadmin',
            self::Admin => 'admin',
            self::Supervisor => 'supervisor',
            self::Teacher => 'teacher',
            self::Guardian => 'guardian',
            self::Student => 'student',
        };
    }

    /**
     * الدور الإداري هو ما يُنشأ يدوياً من شاشة المستخدمين — وما عداه يولّده النظام
     * تلقائياً مع سجلّه (أستاذ/ولي أمر/طالب).
     *
     * وهي القسمة نفسها التي تحكم كلمة المرور: الإداري يغيّر كلمته بنفسه، وغيره
     * تُدار كلمتُه من اللوحة وحدها كي تبقى قابلةً للطباعة والتوزيع.
     */
    public function isAdministrative(): bool
    {
        return $this->linkedRecord() === null;
    }

    /**
     * السجلّ الذي يلزم ربط الحساب به ليعمل نطاق المعهد والـ API.
     */
    public function linkedRecord(): ?string
    {
        return match ($this) {
            self::Teacher => 'teacher',
            self::Guardian => 'guardian',
            self::Student => 'student',
            default => null,
        };
    }

    /**
     * @return array<int, string>
     */
    public static function names(): array
    {
        return array_column(self::cases(), 'value');
    }

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return collect(self::cases())->mapWithKeys(fn (self $case) => [$case->value => $case->label()])->all();
    }

    public static function labelOf(string $name): string
    {
        return self::tryFrom($name)?->label() ?? $name;
    }
}
