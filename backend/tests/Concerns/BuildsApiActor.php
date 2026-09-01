<?php

namespace Tests\Concerns;

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

    protected function assignInstituteRole(User $user, Institute $institute, string $role): void
    {
        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);
        $user->assignRole($role);
    }
}
