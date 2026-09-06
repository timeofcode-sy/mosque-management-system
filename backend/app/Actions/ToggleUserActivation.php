<?php

namespace App\Actions;

use App\Models\User;
use RuntimeException;

/**
 * إقفال حسابٍ أو فتحه.
 *
 * الحسابُ المقفل يُرفض عند الدخول وتسقط رموزُه في EnsureUserIsActive، ولا يُحذف:
 * سجلّاتُ الحضور والتلاوة معلّقةٌ به.
 *
 * أغلبُ الإقفال يقع تلقائياً حين يتغيّر حال السجلّ (منسحب، منتهي الخدمة) في
 * App\Observers؛ وهذا الإجراء للحالات اليدوية.
 */
class ToggleUserActivation
{
    public function handle(User $actor, User $user, bool $active): void
    {
        if (! $actor->can('users.manage')) {
            throw new RuntimeException('لا تملك صلاحية إدارة الحسابات.');
        }

        if ($actor->is($user)) {
            throw new RuntimeException('لا يمكنك إقفال حسابك.');
        }

        if (! AssignUserRole::outranks($actor, $user)) {
            throw new RuntimeException('لا تملك إقفال هذا الحساب.');
        }

        $user->forceFill(['is_active' => $active])->save();
    }
}
