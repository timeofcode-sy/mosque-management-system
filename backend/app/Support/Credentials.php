<?php

namespace App\Support;

use App\Enums\PanelRole;
use Illuminate\Support\Facades\DB;

/**
 * توليد بيانات الدخول: اسم مستخدم فريد وكلمة مرور من ثماني خانات رقمية.
 *
 * التفرّد على مستوى النظام كلّه لا داخل المعهد، لأن اسم المستخدم هو مفتاح الدخول
 * وحده — لو رُقّم داخل كل معهد لتصادم طالبان من معهدين على الاسم نفسه.
 *
 * كلمة المرور أرقامٌ صرفة عن قصد: تُملى على طفل وتُطبع في بطاقة. ضعفُها النظري
 * (١٠⁸ احتمالاً) يقابله خنقُ محاولات الدخول في FortifyServiceProvider.
 */
class Credentials
{
    /** أول رقم في تسلسل كل دور — ليبدأ الاسم بأربع خانات لا بواحدة. */
    private const FIRST_SEQUENCE = 1000;

    private const PASSWORD_DIGITS = 8;

    /**
     * كلمة مرور عشوائية من ثماني خانات رقمية، تُقبل فيها الأصفار البادئة.
     */
    public static function password(): string
    {
        return str_pad((string) random_int(0, 10 ** self::PASSWORD_DIGITS - 1), self::PASSWORD_DIGITS, '0', STR_PAD_LEFT);
    }

    /**
     * اسم مستخدم فريد على صيغة «بادئة الدور + رقم متسلسل»، مثل student2395.
     *
     * الرقم يُستنبط من أكبر اسم قائم للبادئة نفسها لا من عدّ الصفوف: الحذف يترك
     * ثغرات في العدّ فيعيد استعمال اسمٍ سبق أن وُزّع.
     */
    public static function username(PanelRole $role): string
    {
        $prefix = $role->usernamePrefix();
        $sequence = max(self::lastSequence($prefix) + 1, self::FIRST_SEQUENCE);

        while (self::taken($username = $prefix.$sequence)) {
            $sequence++;
        }

        return $username;
    }

    private static function lastSequence(string $prefix): int
    {
        $offset = mb_strlen($prefix) + 1;

        return (int) DB::table('users')
            ->where('username', 'like', $prefix.'%')
            ->max(DB::raw("CAST(SUBSTR(username, {$offset}) AS INTEGER)"));
    }

    private static function taken(string $username): bool
    {
        return DB::table('users')->where('username', $username)->exists();
    }
}
