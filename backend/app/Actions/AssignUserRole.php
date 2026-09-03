<?php

namespace App\Actions;

use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\DB;
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
            self::roleNamesOf($actor),
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
        $pivotTable = config('permission.table_names.model_has_roles');
        $rolesTable = config('permission.table_names.roles');

        return DB::table($pivotTable)
            ->join($rolesTable, "{$rolesTable}.id", '=', $pivotTable.'.'.(config('permission.column_names.role_pivot_key') ?: 'role_id'))
            ->where("{$pivotTable}.model_type", $user->getMorphClass())
            ->where($pivotTable.'.'.config('permission.column_names.model_morph_key'), $user->getKey())
            ->pluck("{$rolesTable}.name")
            ->unique()
            ->values()
            ->all();
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
