<?php

namespace App\Actions;

use App\Enums\PanelRole;
use App\Enums\StudentStatus;
use App\Enums\TeacherStatus;
use App\Models\Guardian;
use App\Models\Institute;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use App\Support\Credentials;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Role;

/**
 * توليد حساب دخول لسجلّ أستاذ أو ولي أمر أو طالب.
 *
 * الاتجاه هنا معكوسٌ عن InviteUser: هناك يُنشأ الحسابُ أولاً فيُشتقّ منه سجلّ،
 * وهنا السجلّ هو الأصل والحسابُ تابعٌ يولَّد معه. ولذلك يُستدعى من مراقبي النماذج
 * (App\Observers) لا من الشاشات: أياً كان طريق إنشاء الطالب — استمارةُ تسجيل أو
 * بذرةٌ أو مزامنةٌ من التطبيق — يخرج ومعه حسابُه.
 *
 * الإجراء عديم الأثر عند التكرار: سجلٌّ مرتبطٌ بحساب لا يُولَّد له ثانٍ.
 */
class GenerateAccount
{
    public function __construct(private readonly AssignUserRole $assignRole) {}

    /**
     * @return array{user: User, password: string}|null null إن كان السجلّ مرتبطاً أصلاً
     */
    public function handle(Model $record): ?array
    {
        $role = $this->roleOf($record);
        $institute = $record->institute_id ? Institute::find($record->institute_id) : null;

        if ($role === null || $institute === null || $record->user_id !== null) {
            return null;
        }

        /** الحساب بلا دوره لا يفتح شيئاً — فحيث لا أدوار مبذورة لا حسابات تولَّد */
        if (! Role::query()->where('name', $role->value)->where('guard_name', 'web')->exists()) {
            return null;
        }

        return DB::transaction(function () use ($record, $role, $institute): array {
            $password = Credentials::password();

            $user = User::create([
                ...$this->nameOf($record),
                'username' => Credentials::username($role),
                'phone' => $record->phone,
                'password' => $password,
                'is_active' => $this->isActive($record),
            ]);

            /** النسخة المقروءة خارج الإسناد الجَماعي عمداً: سرٌّ لا يُملأ من طلب */
            $user->forceFill(['generated_password' => $password])->save();

            $this->assignRole->system($user, $role, $institute);
            $record->forceFill(['user_id' => $user->id])->save();

            return ['user' => $user, 'password' => $password];
        });
    }

    /**
     * يوافق حالةَ الحساب حالةَ سجلّه: المنسحب والمنتهية خدمتُه لا يدخلان.
     */
    public function syncActivation(Model $record): void
    {
        $user = $record->user_id ? User::find($record->user_id) : null;

        if ($user === null) {
            return;
        }

        $user->forceFill(['is_active' => $this->isActive($record)])->save();
    }

    private function roleOf(Model $record): ?PanelRole
    {
        return match (true) {
            $record instanceof Teacher => PanelRole::Teacher,
            $record instanceof Guardian => PanelRole::Guardian,
            $record instanceof Student => PanelRole::Student,
            default => null,
        };
    }

    /**
     * حقول الاسم في جدول users مطلوبة، وأسماء السجلّات مخزَّنة على صيغٍ مختلفة:
     * الطالب مفكَّك، والأستاذ وولي الأمر اسمٌ واحد يُقسم عند أول فراغ.
     *
     * @return array<string, string|null>
     */
    private function nameOf(Model $record): array
    {
        if ($record instanceof Student) {
            return [
                'first_name' => $record->first_name,
                'last_name' => $record->family_name,
                'father_name' => $record->father_name,
            ];
        }

        $full = trim((string) ($record instanceof Teacher ? $record->display_name : $record->full_name));
        $parts = preg_split('/\s+/u', $full, 2) ?: [$full];

        return [
            'first_name' => $parts[0] !== '' ? $parts[0] : '—',
            'last_name' => $parts[1] ?? '',
        ];
    }

    private function isActive(Model $record): bool
    {
        if ($record->trashed()) {
            return false;
        }

        return match (true) {
            $record instanceof Student => $record->status === StudentStatus::Active,
            $record instanceof Teacher => $record->status === TeacherStatus::Active,
            default => true,
        };
    }
}
