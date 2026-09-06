<?php

namespace App\Actions;

use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use Illuminate\Support\Facades\App;
use RuntimeException;
use Spatie\Permission\PermissionRegistrar;

/**
 * إسناد دور لمستخدم داخل معهد بعينه، أو خارج المعاهد كلها إن كان الدور عابراً.
 *
 * الحراسة هنا لا في الواجهة: لا يُسند أحدٌ دوراً أعلى من دوره، فمدير المعهد لا يصنع
 * مشرفاً أعلى ولا مبرمجاً. إخفاء الخيار من القائمة ليس حمايةً — الطلب يصل إلى الخادم
 * كيفما بُنيت الواجهة.
 */
class AssignUserRole
{
    public function handle(User $actor, User $user, PanelRole $role, ?Institute $institute = null): void
    {
        self::assertAssignable($actor, $role);

        if ($role->isGlobal()) {
            $user->assignGlobalRole($role->value);

            return;
        }

        if ($institute === null) {
            throw new RuntimeException('الدور المرتبط بمعهد يحتاج تحديد المعهد.');
        }

        $this->withinInstitute($institute, fn () => $user->assignRole($role->value));
    }

    /**
     * إسنادٌ بلا حراسة هرمية — للتوليد الآلي حيث لا فاعلَ بشرياً يُقاس إليه.
     *
     * الإذن هنا سبق أن فُحص عند إنشاء السجلّ نفسه (طالبٌ لا ينشئه إلا من يملك
     * students.manage)، والحساب تابعٌ للسجلّ لا قرارٌ مستقل.
     */
    public function system(User $user, PanelRole $role, Institute $institute): void
    {
        $this->withinInstitute($institute, fn () => $user->assignRole($role->value));
    }

    /**
     * الأدوار التي يحقّ لهذا المستخدم إسنادها — رتبتها ليست أعلى من رتبته.
     *
     * @return array<int, PanelRole>
     */
    public static function assignableRoles(User $actor): array
    {
        $rank = self::rankOf($actor);

        return array_values(array_filter(
            PanelRole::cases(),
            fn (PanelRole $role): bool => $role->rank() >= $rank,
        ));
    }

    /**
     * الأدوار التي يُنشئ هذا المستخدم حساباتها يدوياً — الإدارية منها وحدها.
     *
     * فمدير المعهد يرى «مدير معهد» و«مشرف» لا أكثر، والمشرف الأعلى يرى فوقهما
     * دورَه؛ أما الأستاذ وولي الأمر والطالب فلا تُنشأ حساباتهم من هنا أصلاً بل
     * يولّدها النظام مع سجلّاتهم.
     *
     * @return array<int, PanelRole>
     */
    public static function creatableRoles(User $actor): array
    {
        return array_values(array_filter(
            self::assignableRoles($actor),
            fn (PanelRole $role): bool => $role->isAdministrative(),
        ));
    }

    /**
     * هل يعلو الفاعلُ الهدفَ رتبةً؟ عليها تقوم إدارة بيانات الدخول: لا يرى مشرفٌ
     * كلمةَ مشرفٍ آخر ولا يبدّلها، ولا مديرُ معهدٍ كلمةَ مديرٍ نظيره.
     */
    public static function outranks(User $actor, User $target): bool
    {
        return self::rankOf($actor) < self::rankOf($target);
    }

    public static function assertAssignable(User $actor, PanelRole $role): void
    {
        if (! in_array($role, self::assignableRoles($actor), true)) {
            throw new RuntimeException("لا تملك صلاحية إسناد دور «{$role->label()}».");
        }
    }

    /**
     * رتبة المستخدم هي أعلى أدواره في كل المعاهد — ومن لا دور له لا يُسند شيئاً.
     */
    public static function rankOf(User $actor): int
    {
        $ranks = array_map(
            fn (string $name): int => PanelRole::tryFrom($name)?->rank() ?? PHP_INT_MAX,
            $actor->allRoleNames(),
        );

        return $ranks === [] ? PHP_INT_MAX : min($ranks);
    }

    /**
     * كل أدوار المستخدم عبر كل المعاهد — لا عبر علاقة spatie المقيّدة بالمعهد الحالي.
     *
     * @return array<int, string>
     */
    public static function roleNamesOf(User $user): array
    {
        return $user->allRoleNames();
    }

    /**
     * ينفّذ داخل نطاق معهد ثم يعيد مفتاح الفريق كما كان، فلا يتسرّب نطاقُ الإسناد
     * إلى بقيّة الطلب.
     */
    private function withinInstitute(Institute $institute, callable $callback): void
    {
        $registrar = App::make(PermissionRegistrar::class);
        $previous = $registrar->getPermissionsTeamId();

        $registrar->setPermissionsTeamId($institute->id);

        try {
            $callback();
        } finally {
            $registrar->setPermissionsTeamId($previous);
        }
    }
}
