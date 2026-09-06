<?php

namespace App\Actions;

use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use App\Support\Credentials;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * إنشاء حساب إداري يدوياً: مبرمج، مشرف أعلى، مدير معهد، أو مشرف.
 *
 * ما عدا هذه الأربعة لا يُنشأ من هنا — حسابُ الأستاذ وولي الأمر والطالب يولّده
 * GenerateAccount مع سجلّه، وإتاحته يدوياً هنا كانت تُنتج حساباً بلا سجلٍّ حقيقي
 * يرفضه ApiScope بـ 422.
 *
 * لا إرسال بريد ولا رابط تعيين: القناة غير مهيّأة، والبريد صار اختيارياً أصلاً.
 * بدلاً منه تُعرض بيانات الدخول المولَّدة مرّةً بعد الإنشاء، وتبقى في
 * generated_password ليُعاد عرضها لمن يعلو صاحبَها رتبةً.
 */
class InviteUser
{
    public function __construct(private readonly AssignUserRole $assignRole) {}

    /**
     * @param  array<string, mixed>  $attributes  first_name · last_name · email? · phone?
     * @return array{user: User, password: string}
     */
    public function handle(User $actor, array $attributes, PanelRole $role, ?Institute $institute = null): array
    {
        AssignUserRole::assertAssignable($actor, $role);

        if (! $role->isAdministrative()) {
            throw new RuntimeException("حسابات «{$role->label()}» يولّدها النظام مع سجلّها ولا تُنشأ من هنا.");
        }

        if (! $role->isGlobal() && $institute === null) {
            throw new RuntimeException('الدور المرتبط بمعهد يحتاج تحديد المعهد.');
        }

        $password = Credentials::password();

        $user = DB::transaction(function () use ($attributes, $role, $institute, $actor, $password): User {
            $user = User::create([
                ...$attributes,
                'username' => Credentials::username($role),
                'password' => $password,
            ]);

            /** النسخة المقروءة خارج الإسناد الجَماعي عمداً: سرٌّ لا يُملأ من طلب */
            $user->forceFill(['generated_password' => $password])->save();

            $this->assignRole->handle($actor, $user, $role, $institute);

            return $user;
        });

        return ['user' => $user, 'password' => $password];
    }
}
