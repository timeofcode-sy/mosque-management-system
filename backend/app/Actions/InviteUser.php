<?php

namespace App\Actions;

use App\Enums\PanelRole;
use App\Models\Guardian;
use App\Models\Institute;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * إنشاء حساب دخول وإسناد دوره وربطه بسجلّه.
 *
 * الربط بالسجلّ (أستاذ/ولي أمر/طالب) ليس تحسيناً: نطاقُ المعهد في اللوحة والـ API
 * مشتقٌّ منه، وحسابٌ بلا سجلّ يُرفض في ApiScope بـ 422 — أي أن تطبيقات فلاتر لا تفتح
 * له أصلاً.
 *
 * لا إرسال بريد: لا قناة إرسال مهيّأة في المشروع. بدلاً منه يُولَّد رابط تعيين كلمة
 * مرور يُعرض مرّةً واحدة بعد الإنشاء لينسخه المشرف بنفسه.
 */
class InviteUser
{
    public function __construct(private readonly AssignUserRole $assignRole) {}

    /**
     * @param  array<string, mixed>  $attributes  first_name · last_name · email · phone?
     * @return array{user: User, reset_url: string}
     */
    public function handle(User $actor, array $attributes, PanelRole $role, ?Institute $institute = null, ?Model $record = null): array
    {
        AssignUserRole::assertAssignable($actor, $role);

        if (! $role->isGlobal() && $institute === null) {
            throw new RuntimeException('الدور المرتبط بمعهد يحتاج تحديد المعهد.');
        }

        $user = DB::transaction(function () use ($attributes, $role, $institute, $actor, $record): User {
            $user = User::create([
                ...$attributes,
                'password' => Str::password(24),
            ]);

            $this->assignRole->handle($actor, $user, $role, $institute);
            $this->linkRecord($user, $role, $institute, $record);

            return $user;
        });

        return ['user' => $user, 'reset_url' => $this->resetUrl($user)];
    }

    /**
     * يربط الحساب بسجلّ قائم إن مُرِّر، وإلا أنشأ سجلاً بأدنى ما يلزم ليبدأ العمل.
     */
    private function linkRecord(User $user, PanelRole $role, ?Institute $institute, ?Model $record): void
    {
        $kind = $role->linkedRecord();

        if ($kind === null || $institute === null) {
            return;
        }

        if ($record !== null) {
            $record->forceFill(['user_id' => $user->id])->save();

            return;
        }

        match ($kind) {
            'teacher' => Teacher::create([
                'institute_id' => $institute->id,
                'user_id' => $user->id,
                'display_name' => $user->name,
            ]),
            'guardian' => Guardian::create([
                'institute_id' => $institute->id,
                'user_id' => $user->id,
                'full_name' => $user->name,
            ]),
            /** اسم الأب مطلوب في جدول الطلاب؛ يُؤخذ من الحساب وإلا فاسم العائلة سدّاً للفراغ */
            'student' => Student::create([
                'institute_id' => $institute->id,
                'user_id' => $user->id,
                'first_name' => $user->first_name,
                'father_name' => $user->father_name ?: $user->last_name,
                'family_name' => $user->last_name,
            ]),
            default => null,
        };
    }

    /**
     * رابط تعيين كلمة المرور — رمز Fortify نفسه الذي يستعمله «نسيت كلمة المرور».
     */
    private function resetUrl(User $user): string
    {
        return route('password.reset', [
            'token' => Password::broker()->createToken($user),
            'email' => $user->email,
        ]);
    }
}
