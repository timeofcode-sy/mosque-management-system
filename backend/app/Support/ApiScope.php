<?php

namespace App\Support;

use App\Models\Institute;
use App\Models\User;
use Illuminate\Support\Facades\App;
use RuntimeException;
use Spatie\Permission\PermissionRegistrar;

/**
 * يحسم نطاق مستخدم Sanctum (المعهد، وحلقاته إن كان أستاذاً، وأبناؤه إن كان ولي أمر).
 *
 * نظير App\Concerns\InteractsWithInstitute لكن بلا جلسة ولا مكوّن Livewire: كل طلب API
 * يحسم نطاقه من حساب المستخدم نفسه (teacher/guardian/student)، ولا يوجد سقوط افتراضي
 * إلى "أول معهد نشط" كما في اللوحة — رمز بلا معهد مرتبط يُرفض صراحةً.
 */
class ApiScope
{
    public function __construct(private readonly User $user) {}

    public function institute(): Institute
    {
        $instituteId = $this->user->teacher?->institute_id
            ?? $this->user->guardian?->institute_id
            ?? $this->user->student?->institute_id;

        $institute = $instituteId ? Institute::find($instituteId) : null;

        if ($institute === null) {
            throw new RuntimeException('لا يملك هذا المستخدم معهداً مرتبطاً.');
        }

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);

        return $institute;
    }

    public function scopeKey(): string
    {
        return 'institute:'.$this->institute()->uuid;
    }

    public static function for(User $user): self
    {
        return new self($user);
    }
}
