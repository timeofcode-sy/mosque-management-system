<?php

namespace App\Queries;

use App\Actions\AssignUserRole;
use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * بيانات دخول منتسبي معهد، جاهزةً للعرض والطباعة والتصدير.
 *
 * ثلاثة قيود تحكم ما يُرى: المعهد (من إسناد الدور فيه)، والرتبة (لا يرى أحدٌ بيانات
 * من يساويه أو يعلوه، فلا يطّلع مشرفٌ على كلمة مشرفٍ نظيره)، ووجودُ نسخة مقروءة من
 * كلمة المرور — فمن بدّل كلمته بنفسه لا تُعرض كلمتُه بل يُقال إنها مُغيَّرة.
 *
 * حاملُ دورٍ عابر للمعاهد مستثنى كلّه: هؤلاء لا تُطبع لهم بطاقات.
 */
class CredentialQuery
{
    /**
     * الأدوار التي تُطبع بطاقاتها.
     *
     * @return array<int, PanelRole>
     */
    public static function roles(): array
    {
        return [PanelRole::Student, PanelRole::Guardian, PanelRole::Teacher, PanelRole::Supervisor, PanelRole::Admin];
    }

    /**
     * @return Collection<int, array{id: int, name: string, role: string, username: ?string, password: ?string, is_active: bool, detail: ?string}>
     */
    public function rows(
        Institute $institute,
        User $viewer,
        string $role = '',
        string $search = '',
        ?int $courseCircleId = null,
    ): Collection {
        $viewerRank = AssignUserRole::rankOf($viewer);
        $names = $this->visibleRoleNames($role, $viewerRank);

        if ($names === []) {
            return new Collection;
        }

        $users = User::query()
            ->with([
                'teacher:id,user_id,display_name',
                'guardian:id,user_id,full_name',
                'student:id,user_id,first_name,father_name,family_name,registration_no',
            ])
            ->addSelect(['panel_role' => $this->assignmentQuery($institute, $names)->select($this->rolesTable().'.name')->limit(1)])
            ->whereNotNull('username')
            ->whereExists(fn ($query) => $this->assignmentQuery($institute, $names, $query))
            ->whereNotExists(fn ($query) => $this->assignmentQuery(null, User::GLOBAL_ROLES, $query))
            ->when($search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('first_name', 'like', "%{$search}%")
                ->orWhere('last_name', 'like', "%{$search}%")
                ->orWhere('username', 'like', "%{$search}%")))
            ->when($courseCircleId !== null, fn ($query) => $query->whereHas(
                'student.enrollments',
                fn ($enrollment) => $enrollment->where('course_circle_id', $courseCircleId),
            ))
            ->orderBy('first_name')
            ->orderBy('last_name')
            ->get();

        return $users->map(fn (User $user): array => [
            'id' => $user->id,
            'name' => $this->displayName($user),
            'role' => PanelRole::labelOf((string) $user->panel_role),
            'username' => $user->username,
            'password' => $user->generated_password,
            'is_active' => (bool) $user->is_active,
            'detail' => $this->detail($user),
        ])->values();
    }

    /**
     * الأدوار المعروضة: المطلوبُ منها إن حُدّد، وكلُّها إن لم يُحدّد — ثم يُطرح منها
     * ما لا يعلوه الناظرُ رتبةً.
     *
     * @return array<int, string>
     */
    private function visibleRoleNames(string $role, int $viewerRank): array
    {
        return array_values(array_map(
            fn (PanelRole $case): string => $case->value,
            array_filter(
                self::roles(),
                fn (PanelRole $case): bool => $case->rank() > $viewerRank && ($role === '' || $case->value === $role),
            ),
        ));
    }

    /**
     * إسنادُ أيٍّ من هذه الأدوار داخل المعهد — أو خارج المعاهد كلها إن كان null.
     *
     * @param  array<int, string>  $names
     */
    private function assignmentQuery(?Institute $institute, array $names, $query = null)
    {
        $pivotTable = config('permission.table_names.model_has_roles');
        $rolesTable = $this->rolesTable();

        $query ??= DB::query();

        return $query->from($pivotTable)
            ->join($rolesTable, "{$rolesTable}.id", '=', $pivotTable.'.'.(config('permission.column_names.role_pivot_key') ?: 'role_id'))
            ->whereColumn($pivotTable.'.'.config('permission.column_names.model_morph_key'), 'users.id')
            ->where("{$pivotTable}.model_type", (new User)->getMorphClass())
            ->where($pivotTable.'.'.config('permission.column_names.team_foreign_key'), $institute?->id ?? User::GLOBAL_TEAM_ID)
            ->whereIn("{$rolesTable}.name", $names);
    }

    private function rolesTable(): string
    {
        return config('permission.table_names.roles');
    }

    /**
     * اسم السجلّ لا اسم الحساب: الحساب مشتقٌّ منه وقد قُسّم عند أول فراغ.
     */
    private function displayName(User $user): string
    {
        return match (true) {
            $user->student !== null => trim("{$user->student->first_name} {$user->student->father_name} {$user->student->family_name}"),
            $user->teacher !== null => $user->teacher->display_name,
            $user->guardian !== null => $user->guardian->full_name,
            default => $user->name,
        };
    }

    private function detail(User $user): ?string
    {
        return $user->student?->registration_no ?? $user->phone;
    }
}
