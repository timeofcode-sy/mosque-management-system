<?php

namespace App\Support;

use App\Models\Institute;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Session;
use Spatie\Permission\PermissionRegistrar;

/**
 * نطاق لوحة الويب: في أيّ معهد يعمل المستخدم الآن، وإلى أيّها يحقّ له التبديل.
 *
 * نظير App\Support\ApiScope لكن بجلسة. الفرق الجوهري عن السابق أن السقوط الافتراضي
 * إلى «أوّل معهد فعّال» لم يعد مفتوحاً للجميع — كان ذلك تسريباً عبر المعاهد يُدخل
 * الطالبَ وولي الأمر إلى بيانات معهد لا صلة لهما به — بل اقتصر على من يملك دوراً
 * عابراً للمعاهد، وهو يراها كلها أصلاً.
 */
class PanelScope
{
    /**
     * المعهد العامل: ما ثُبِّت في الجلسة، وإلا معهد سجلّ المستخدم، وإلا السقوط المسموح.
     */
    public static function resolve(?User $user = null): ?Institute
    {
        $user ??= Auth::user();

        if ($user === null) {
            return null;
        }

        $institute = self::fromSession($user) ?? self::homeInstitute($user) ?? self::fallback($user);

        if ($institute !== null) {
            self::activate($institute);
        }

        return $institute;
    }

    /**
     * التبديل إلى معهد آخر — يُرفض ما لم يكن للمستخدم فيه دور أو كان عابراً للمعاهد.
     */
    public static function switchTo(Institute $institute, ?User $user = null): bool
    {
        $user ??= Auth::user();

        if ($user === null || ! self::canAccess($user, $institute)) {
            return false;
        }

        self::activate($institute);

        return true;
    }

    public static function canAccess(User $user, Institute $institute): bool
    {
        return $user->canAccessInstitute($institute);
    }

    /**
     * المعاهد التي يظهرها المبدّل: كلها للعابر للمعاهد، وما للمستخدم فيه دور أو سجلّ لغيره.
     *
     * @return Collection<int, Institute>
     */
    public static function institutesFor(User $user): Collection
    {
        if ($user->hasGlobalRole()) {
            return Institute::query()->orderByDesc('is_active')->orderBy('name')->get();
        }

        return Institute::query()->whereIn('id', self::instituteIdsFor($user))->orderBy('name')->get();
    }

    /**
     * معهد المستخدم الأصلي — ما يُقاس عليه شريطُ التنبيه حين يعمل في معهد سواه.
     */
    public static function homeInstitute(?User $user = null): ?Institute
    {
        $user ??= Auth::user();

        if ($user === null) {
            return null;
        }

        $instituteId = $user->homeInstituteId();

        return $instituteId ? Institute::find($instituteId) : null;
    }

    /**
     * تثبيت المعهد في الجلسة وضبط مفتاح الفريق في spatie معاً — الاثنان لا ينفصلان،
     * فبلا مفتاح الفريق تعود can() بـ false على كل صلاحية مسنَدة داخل معهد.
     */
    public static function activate(Institute $institute): void
    {
        Session::put('institute_id', $institute->id);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);
    }

    /**
     * المعاهد التي للمستخدم فيها سجلّ أو دور مسنَد.
     *
     * @return array<int, int>
     */
    public static function instituteIdsFor(User $user): array
    {
        return $user->instituteIds();
    }

    private static function fromSession(User $user): ?Institute
    {
        $instituteId = Session::get('institute_id');

        if (! $instituteId) {
            return null;
        }

        $institute = Institute::find($instituteId);

        if ($institute !== null && self::canAccess($user, $institute)) {
            return $institute;
        }

        // معهد الجلسة لم يعد قائماً أو لم يعد من حقّ المستخدم — لا يُترك ليُعاد استعماله.
        Session::forget('institute_id');

        return null;
    }

    /**
     * السقوط الافتراضي: للعابر للمعاهد وحده، فهو يرى المعاهد كلها على أي حال.
     */
    private static function fallback(User $user): ?Institute
    {
        if (! $user->hasGlobalRole()) {
            return null;
        }

        return Institute::query()->where('is_active', true)->orderBy('id')->first();
    }
}
