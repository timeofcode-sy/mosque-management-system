<?php

namespace App\Models;

use App\Casts\DateOnly;
// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Fortify\Contracts\PasskeyUser;
use Laravel\Fortify\PasskeyAuthenticatable;
use Laravel\Fortify\TwoFactorAuthenticatable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\PermissionRegistrar;
use Spatie\Permission\Traits\HasRoles;

#[Fillable(['first_name', 'last_name', 'father_name', 'date_birth', 'place_birth', 'email', 'phone', 'password'])]
#[Hidden(['password', 'two_factor_secret', 'two_factor_recovery_codes', 'remember_token'])]
class User extends Authenticatable implements PasskeyUser
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasRoles, Notifiable, PasskeyAuthenticatable, TwoFactorAuthenticatable;

    /**
     * مفتاح الفريق الذي تُسنَد تحته الأدوار العابرة للمعاهد.
     *
     * ليس معهداً — لا صفر في جدول institutes. واختير صفراً لا فراغاً لأن العمود
     * model_has_roles.institute_id جزءٌ من المفتاح الأساسي فلا يقبل NULL.
     */
    public const GLOBAL_TEAM_ID = 0;

    /**
     * أسماء الأدوار المسنَدة خارج كل معهد.
     *
     * @var array<int, string>
     */
    public const GLOBAL_ROLES = ['developer', 'super_admin'];

    /**
     * ذاكرة الطلب الواحد: Gate::before يُستدعى مع كل فحص صلاحية، ولا يصحّ أن
     * يستعلم قاعدة البيانات في كل مرّة.
     *
     * @var array<int, string>|null
     */
    private ?array $globalRoles = null;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'date_birth' => DateOnly::class,
            'password' => 'hashed',
        ];
    }

    /**
     * الاسم المعروض للمستخدم في الواجهات والتقارير.
     */
    protected function name(): Attribute
    {
        return Attribute::get(fn (): string => trim("{$this->first_name} {$this->last_name}"));
    }

    public function teacher(): HasOne
    {
        return $this->hasOne(Teacher::class);
    }

    public function guardian(): HasOne
    {
        return $this->hasOne(Guardian::class);
    }

    public function student(): HasOne
    {
        return $this->hasOne(Student::class);
    }

    /**
     * أسماء الأدوار العابرة للمعاهد المسنَدة لهذا المستخدم.
     *
     * استعلامٌ مباشر على model_has_roles لا عبر علاقة spatie: تلك مقيَّدة بالمعهد
     * الحالي بحكم وضع الفرق، وهذه الأدوار مسنَدة خارج كل معهد.
     *
     * @return array<int, string>
     */
    public function globalRoleNames(): array
    {
        if ($this->globalRoles !== null) {
            return $this->globalRoles;
        }

        if (! $this->exists) {
            return $this->globalRoles = [];
        }

        $pivotTable = config('permission.table_names.model_has_roles');
        $rolesTable = config('permission.table_names.roles');

        return $this->globalRoles = DB::table($pivotTable)
            ->join($rolesTable, "{$rolesTable}.id", '=', $pivotTable.'.'.(config('permission.column_names.role_pivot_key') ?: 'role_id'))
            ->where("{$pivotTable}.model_type", $this->getMorphClass())
            ->where($pivotTable.'.'.config('permission.column_names.model_morph_key'), $this->getKey())
            ->where($pivotTable.'.'.config('permission.column_names.team_foreign_key'), self::GLOBAL_TEAM_ID)
            ->pluck("{$rolesTable}.name")
            ->all();
    }

    /**
     * هل يحمل المستخدم دوراً عابراً للمعاهد؟ عليها يقوم Gate::before.
     *
     * @param  array<int, string>|string  $roles
     */
    public function hasGlobalRole(array|string $roles = self::GLOBAL_ROLES): bool
    {
        return array_intersect((array) $roles, $this->globalRoleNames()) !== [];
    }

    /**
     * إسناد دور خارج نطاق كل معهد، ثم إعادة مفتاح الفريق كما كان حتى لا يتسرّب
     * النطاق العام إلى ما بعد الاستدعاء.
     */
    public function assignGlobalRole(string $role): void
    {
        $this->withGlobalTeam(fn () => $this->assignRole($role));
    }

    /**
     * سحب دور عابر للمعاهد.
     */
    public function removeGlobalRole(string $role): void
    {
        $this->withGlobalTeam(fn () => $this->removeRole($role));
    }

    /**
     * Get the user's initials
     */
    public function initials(): string
    {
        return Str::of($this->first_name.' '.$this->last_name)
            ->explode(' ')
            ->take(2)
            ->map(fn ($word) => Str::substr($word, 0, 1))
            ->implode('');
    }

    private function withGlobalTeam(callable $callback): void
    {
        $registrar = App::make(PermissionRegistrar::class);
        $previous = $registrar->getPermissionsTeamId();

        $registrar->setPermissionsTeamId(self::GLOBAL_TEAM_ID);

        try {
            $callback();
        } finally {
            $registrar->setPermissionsTeamId($previous);
        }

        $this->globalRoles = null;
        $this->unsetRelation('roles');
    }
}
