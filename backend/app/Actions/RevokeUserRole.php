<?php

namespace App\Actions;

use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use Illuminate\Support\Facades\App;
use RuntimeException;
use Spatie\Permission\PermissionRegistrar;

/**
 * سحب دور من مستخدم داخل معهد بعينه، أو من النطاق العابر للمعاهد.
 *
 * نفس حراسة الإسناد: من لا يملك منح الدور لا يملك سحبه — وإلا لعزل مديرُ معهدٍ
 * المشرفَ الأعلى.
 */
class RevokeUserRole
{
    public function handle(User $actor, User $user, PanelRole $role, ?Institute $institute = null): void
    {
        AssignUserRole::assertAssignable($actor, $role);

        if ($actor->is($user)) {
            throw new RuntimeException('لا يمكنك سحب دورك من نفسك.');
        }

        if ($role->isGlobal()) {
            $user->removeGlobalRole($role->value);

            return;
        }

        if ($institute === null) {
            throw new RuntimeException('الدور المرتبط بمعهد يحتاج تحديد المعهد.');
        }

        $registrar = App::make(PermissionRegistrar::class);
        $previous = $registrar->getPermissionsTeamId();

        $registrar->setPermissionsTeamId($institute->id);

        try {
            $user->removeRole($role->value);
        } finally {
            $registrar->setPermissionsTeamId($previous);
        }
    }
}
