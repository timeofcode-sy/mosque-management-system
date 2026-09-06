<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\App;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

class RolesAndPermissionsSeeder extends Seeder
{
    /**
     * كل صلاحيات النظام مصنّفة حسب المجال.
     *
     * credentials.export و credentials.manage للمشرف فما فوق: هو من يطبع بطاقات
     * الدخول ويوزّعها على حلقته، ومن يعيد توليد كلمة نسيها طالب. لكنّهما مقيّدتان
     * بالرتبة في AssignUserRole::outranks فلا يبلغ بهما مَن فوقه.
     *
     * @var array<int, string>
     */
    private const PERMISSIONS = [
        'institutes.view', 'institutes.manage',
        'courses.view', 'courses.manage',
        'shifts.manage',
        'circles.view', 'circles.manage',
        'students.view', 'students.manage',
        'teachers.view', 'teachers.manage',
        'guardians.view', 'guardians.manage',
        'enrollments.manage', 'transfers.manage',
        'attendance.view', 'attendance.take', 'attendance.amend', 'attendance.lock',
        'excuses.submit', 'excuses.review',
        'curricula.manage', 'progress.view', 'progress.manage',
        'evaluations.view', 'evaluations.manage',
        'reports.view', 'reports.export',
        'customfields.manage', 'tags.manage',
        'announcements.view', 'announcements.manage',
        'settings.manage', 'users.manage', 'users.invite',
        'credentials.export', 'credentials.manage',
        'sync.pull', 'sync.push', 'conflicts.review',
        'system.debug',
    ];

    /**
     * الأدوار وما يملكه كل دور. النجمة تعني كل الصلاحيات.
     *
     * @var array<string, array<int, string>>
     */
    private const ROLES = [
        'developer' => ['*'],
        'super_admin' => ['*'],
        'admin' => ['*'],
        'supervisor' => [
            'institutes.view', 'courses.view', 'circles.view', 'students.view', 'students.manage',
            'teachers.view', 'guardians.view', 'enrollments.manage', 'transfers.manage',
            'attendance.view', 'attendance.take', 'attendance.amend', 'attendance.lock',
            'excuses.review', 'progress.view', 'progress.manage', 'evaluations.view', 'evaluations.manage',
            'reports.view', 'reports.export', 'announcements.view', 'announcements.manage',
            'credentials.export', 'credentials.manage',
            'sync.pull', 'sync.push', 'conflicts.review',
        ],
        'teacher' => [
            'circles.view', 'students.view', 'attendance.view', 'attendance.take',
            'progress.view', 'progress.manage', 'evaluations.view', 'evaluations.manage',
            'excuses.review', 'reports.view', 'announcements.view',
            'sync.pull', 'sync.push',
        ],
        'guardian' => [
            'students.view', 'attendance.view', 'progress.view', 'evaluations.view',
            'excuses.submit', 'reports.view', 'announcements.view', 'sync.pull',
        ],
        'student' => [
            'attendance.view', 'progress.view', 'evaluations.view', 'announcements.view', 'sync.pull',
        ],
    ];

    /**
     * ما يُنزَع من الأدوار الشاملة — وهو وحده ما يميّز الثلاثة بعضها من بعض.
     *
     * المبرمج يملك كل شيء. المشرف الأعلى مثله عدا أدوات النظام التقنية. ومدير المعهد
     * مثلهما داخل معهده وحده: لا ينشئ معهداً ولا يبدّل بين المعاهد.
     *
     * @var array<string, array<int, string>>
     */
    private const WITHHELD = [
        'super_admin' => ['system.debug'],
        'admin' => ['system.debug', 'institutes.manage'],
    ];

    public function run(): void
    {
        $registrar = App::make(PermissionRegistrar::class);

        /** الأدوار عامة عبر كل المعاهد؛ الإسناد وحده هو المرتبط بمعهد بعينه */
        $registrar->setPermissionsTeamId(null);
        $registrar->forgetCachedPermissions();

        foreach (self::PERMISSIONS as $permission) {
            Permission::findOrCreate($permission, 'web');
        }

        foreach (self::ROLES as $roleName => $permissions) {
            $role = Role::findOrCreate($roleName, 'web');

            $role->syncPermissions($this->permissionsOf($roleName, $permissions));
        }
    }

    /**
     * @param  array<int, string>  $permissions
     * @return array<int, string>
     */
    private function permissionsOf(string $roleName, array $permissions): array
    {
        if ($permissions !== ['*']) {
            return $permissions;
        }

        return array_values(array_diff(self::PERMISSIONS, self::WITHHELD[$roleName] ?? []));
    }
}
