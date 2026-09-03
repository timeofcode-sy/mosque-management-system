<?php

namespace App\Queries;

use App\Models\Institute;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * مستخدمو اللوحة وأدوارهم عبر المعاهد.
 *
 * الأدوار لا تُقرأ من علاقة spatie ($user->roles): تلك مقيّدة بالمعهد الحالي بحكم
 * وضع الفرق، فتُظهر بعض أدوار المستخدم وتُخفي بقيّتها — وهذه شاشةٌ غرضها بالضبط
 * رؤية إسناداته كلها ومعهدَ كلٍّ منها. لذلك تُجلب بضمّة واحدة من model_has_roles
 * لكل الصفحة، لا استعلاماً لكل صفّ.
 */
class UserAdminQuery
{
    /**
     * @return LengthAwarePaginator<int, User>
     */
    public function list(string $search = '', string $role = '', ?int $instituteId = null, int $perPage = 20): LengthAwarePaginator
    {
        $pivotTable = config('permission.table_names.model_has_roles');
        $rolesTable = config('permission.table_names.roles');
        $morphKey = config('permission.column_names.model_morph_key');
        $teamKey = config('permission.column_names.team_foreign_key');

        $matchesAssignment = fn ($query) => $query
            ->from($pivotTable)
            ->join($rolesTable, "{$rolesTable}.id", '=', $pivotTable.'.'.(config('permission.column_names.role_pivot_key') ?: 'role_id'))
            ->whereColumn($pivotTable.'.'.$morphKey, 'users.id')
            ->where("{$pivotTable}.model_type", (new User)->getMorphClass());

        return User::query()
            ->with(['teacher:id,user_id,display_name', 'guardian:id,user_id,full_name', 'student:id,user_id,first_name,family_name'])
            ->when($search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('first_name', 'like', "%{$search}%")
                ->orWhere('last_name', 'like', "%{$search}%")
                ->orWhere('email', 'like', "%{$search}%")))
            ->when($role !== '', fn ($query) => $query->whereExists(
                fn ($sub) => $matchesAssignment($sub)->where("{$rolesTable}.name", $role),
            ))
            ->when($instituteId !== null, fn ($query) => $query->whereExists(
                fn ($sub) => $matchesAssignment($sub)->where($pivotTable.'.'.$teamKey, $instituteId),
            ))
            ->orderBy('first_name')
            ->orderBy('last_name')
            ->paginate($perPage);
    }

    /**
     * إسنادات الأدوار لمجموعة مستخدمين: [معرّف المستخدم => [['role' => …, 'institute' => …], …]].
     *
     * @param  array<int, int>  $userIds
     * @return Collection<int, array<int, array{role: string, institute_id: int, institute: string|null}>>
     */
    public function roleAssignments(array $userIds): Collection
    {
        if ($userIds === []) {
            return new Collection;
        }

        $pivotTable = config('permission.table_names.model_has_roles');
        $rolesTable = config('permission.table_names.roles');
        $teamKey = config('permission.column_names.team_foreign_key');

        $institutes = Institute::query()->pluck('name', 'id');

        return DB::table($pivotTable)
            ->join($rolesTable, "{$rolesTable}.id", '=', $pivotTable.'.'.(config('permission.column_names.role_pivot_key') ?: 'role_id'))
            ->where("{$pivotTable}.model_type", (new User)->getMorphClass())
            ->whereIn($pivotTable.'.'.config('permission.column_names.model_morph_key'), $userIds)
            ->select([
                $pivotTable.'.'.config('permission.column_names.model_morph_key').' as user_id',
                $pivotTable.'.'.$teamKey.' as institute_id',
                "{$rolesTable}.name as role",
            ])
            ->get()
            ->groupBy('user_id')
            ->map(fn (Collection $rows) => $rows->map(fn ($row): array => [
                'role' => (string) $row->role,
                'institute_id' => (int) $row->institute_id,
                'institute' => $institutes->get((int) $row->institute_id),
            ])->values()->all());
    }
}
