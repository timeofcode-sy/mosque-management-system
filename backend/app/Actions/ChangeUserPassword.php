<?php

namespace App\Actions;

use App\Models\User;
use App\Support\Credentials;
use RuntimeException;

/**
 * تبديل كلمة مرور حسابٍ من اللوحة — إمّا بتوليد ثمانية أرقام جديدة أو بكلمةٍ يكتبها
 * المشرف بنفسه.
 *
 * هذا هو الطريق الوحيد لكلمة مرور الطالب وولي الأمر والأستاذ: هم لا يبدّلونها
 * بأنفسهم كي تبقى في generated_password صالحةً للطباعة والتوزيع. أما الإداريون
 * فيبدّلونها من شاشة الأمان، وحينها تُمسح النسخة المشفَّرة فلا يبقى لأحدٍ اطّلاع
 * على ما اختاروه.
 *
 * الحراسة رتبةٌ لا صلاحية وحدها: من يملك credentials.manage يبلغ من دونه رتبةً
 * فقط — فلا يبدّل مشرفٌ كلمةَ مشرفٍ نظيره ولا مديرُ معهدٍ كلمةَ مديرٍ مثله.
 */
class ChangeUserPassword
{
    public function handle(User $actor, User $user, ?string $password = null): string
    {
        if (! $actor->can('credentials.manage')) {
            throw new RuntimeException('لا تملك صلاحية إدارة بيانات الدخول.');
        }

        if (! AssignUserRole::outranks($actor, $user)) {
            throw new RuntimeException('لا تملك تبديل كلمة مرور هذا الحساب.');
        }

        $password ??= Credentials::password();

        $user->forceFill([
            'password' => $password,
            'generated_password' => $password,
        ])->save();

        return $password;
    }
}
