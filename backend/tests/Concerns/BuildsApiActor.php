<?php

namespace Tests\Concerns;

use App\Models\Guardian;
use App\Models\Institute;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;

/**
 * ممثّل مصادَق بتوكن Sanctum لاختبار مسارات API — نظير BuildsInstitute للوحة، لكن بلا جلسة.
 */
trait BuildsApiActor
{
    protected function actingAsTeacher(Institute $institute, ?Teacher $teacher = null): Teacher
    {
        $teacher ??= Teacher::factory()->create(['institute_id' => $institute->id]);
        $user = User::factory()->create();
        $teacher->update(['user_id' => $user->id]);

        $this->assignInstituteRole($user, $institute, 'teacher');
        Sanctum::actingAs($user, ['*']);

        return $teacher->refresh();
    }

    /**
     * حسابٌ إداري بلا سجلّ teacher/guardian/student — كما ينشئه InviteUser تماماً.
     *
     * وهو الحساب الذي كان الـ API يرفضه بـ422 قبل م.6.1، وعليه يقوم الديسكتوب.
     */
    protected function actingAsAdministrator(Institute $institute, string $role = 'admin'): User
    {
        $user = User::factory()->create();

        $this->assignInstituteRole($user, $institute, $role);
        Sanctum::actingAs($user, ['*']);

        return $user;
    }

    /**
     * حاملُ دورٍ عابر للمعاهد (مبرمج/مشرف أعلى) — بلا معهدٍ مسنَد إليه أصلاً.
     */
    protected function actingAsGlobalRole(string $role = 'developer'): User
    {
        $user = User::factory()->create();

        $user->assignGlobalRole($role);
        Sanctum::actingAs($user, ['*']);

        return $user;
    }

    protected function actingAsGuardian(?Institute $institute = null): Guardian
    {
        $institute ??= $this->institute;

        $user = User::factory()->create();
        $guardian = Guardian::factory()->create(['institute_id' => $institute->id, 'user_id' => $user->id]);

        $this->assignInstituteRole($user, $institute, 'guardian');
        Sanctum::actingAs($user, ['*']);

        return $guardian;
    }

    /**
     * حسابٌ بلا سجلٍّ ولا دورٍ في أي معهد — يبقى مرفوضاً بـ422 بعد م.6.1 كما قبلها.
     */
    protected function actingAsOrphan(): User
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user, ['*']);

        return $user;
    }

    protected function assignInstituteRole(User $user, Institute $institute, string $role): void
    {
        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);
        $user->assignRole($role);
    }
}
