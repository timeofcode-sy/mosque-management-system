<?php

namespace App\Support;

use App\Models\Institute;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\App;
use RuntimeException;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\PermissionRegistrar;

/**
 * يحسم نطاق مستخدم Sanctum (المعهد الذي يعمل فيه الآن، وما يحقّ له من معاهد).
 *
 * نظير App\Support\PanelScope لكن بلا جلسة: ما تحسمه هناك الجلسةُ ومبدّلُ المعاهد
 * تحسمه هنا ترويسةُ الطلب X-Institute، والباقي واحد — لأن «في أي معهد يعمل هذا
 * المستخدم» صفةٌ فيه لا في السطح الذي دخل منه (User::instituteIds).
 *
 * 🔄 م.6.1 — الديسكتوب: كان المعهد يُحسم من
 * `user->teacher ?? user->guardian ?? user->student` وحدها، وحسابُ مدير المعهد
 * والمشرف بلا أيٍّ من الثلاثة عمداً (InviteUser) ⇒ 422 على كل نقطة. فكان الـ API
 * جمهورَ التطبيقات وحدها، ولا يدخله مشرفٌ إلا إن كان **أيضاً** أستاذاً مسجَّلاً.
 * صار إسنادُ الدور داخل معهدٍ طريقاً ثانياً إلى النطاق، فعبَره الأربعةُ الذين
 * يخدمهم الديسكتوب — [CLIENTS.md §5 البند 2].
 *
 * وما لم يتغيّر: **لا سقوط افتراضي يخمّن معهداً لصاحب دورٍ داخل معهد**. التخمين على
 * اللوحة يصحّحه المستخدم بالمبدّل الذي أمامه، وعلى الـ API يكتب تفقّداً كاملاً في
 * معهدٍ خطأ بلا أن يلاحظ أحد. والاستثناء الوحيد حاملُ الدور العابر (مبرمج/مشرف أعلى)
 * فهو يرى المعاهد كلها أصلاً — وهو نفسُ استثناء PanelScope::fallback.
 */
class ApiScope
{
    /**
     * ترويسةُ مبدّل المعاهد: uuid المعهد الذي يعمل فيه الجهاز الآن.
     *
     * ترويسةٌ لا معاملُ مسار: النطاق يبقى محسوماً من الحساب في كل نقطة كما في
     * [API.md §4]، وهذه تُضيّق ما يملكه صاحبُ الحساب أصلاً ولا توسّعه — معهدٌ لا
     * يعمل فيه صاحبُ التوكن يُرفض صراحةً لا يُتجاهل بصمت.
     */
    public const HEADER = 'X-Institute';

    public function __construct(
        private readonly User $user,
        private readonly ?string $requestedUuid = null,
    ) {}

    public function institute(): Institute
    {
        $institute = $this->requested()
            ?? $this->home()
            ?? $this->globalFallback();

        if ($institute === null) {
            throw new RuntimeException('لا يملك هذا المستخدم معهداً مرتبطاً.');
        }

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);

        return $institute;
    }

    /**
     * المعاهد التي يحقّ لهذا الحساب أن يعمل فيها — مصدرُ مبدّل المعاهد في الديسكتوب.
     *
     * @return Collection<int, Institute>
     */
    public function institutes(): Collection
    {
        if ($this->user->hasGlobalRole()) {
            return Institute::query()->orderByDesc('is_active')->orderBy('name')->get();
        }

        return Institute::query()
            ->whereIn('id', $this->user->instituteIds())
            ->orderBy('name')
            ->get();
    }

    public function scopeKey(): string
    {
        return 'institute:'.$this->institute()->uuid;
    }

    /**
     * أسماء صلاحيات المستخدم **داخل المعهد العامل** — بها يبني الديسكتوب واجهته.
     *
     * تُقرأ بعد institute() لا قبلها: بلا ضبط مفتاح فريق spatie تعود فارغةً دائماً.
     *
     * والفحصُ بـ can() لكل صلاحية لا بقراءة إسنادات المستخدم مباشرةً: الأدوارُ
     * العابرة (مبرمج/مشرف أعلى) مسنَدةٌ خارج المعاهد فلا تظهر في إسنادات هذا المعهد،
     * وما يمنحها هو Gate::before في AppServiceProvider. وقراءةُ الإسنادات كانت تعيد
     * للمبرمج قائمةً فارغة فيفتح الديسكتوبَ بلا بابٍ واحد.
     *
     * @return array<int, string>
     */
    public function permissions(): array
    {
        $this->institute();

        return Permission::query()
            ->orderBy('name')
            ->pluck('name')
            ->filter(fn (string $name): bool => $this->user->can($name))
            ->values()
            ->all();
    }

    public static function for(User $user, ?string $instituteUuid = null): self
    {
        return new self($user, $instituteUuid ?? self::requestedUuid());
    }

    /**
     * المعهد المطلوب في الترويسة — ويُرفض إن لم يكن من حقّ صاحب التوكن.
     */
    private function requested(): ?Institute
    {
        if (blank($this->requestedUuid)) {
            return null;
        }

        $institute = Institute::query()->where('uuid', $this->requestedUuid)->first();

        // 403 لا 422: الحساب له معهدٌ يعمل فيه، والمرفوض طلبُه العملَ في غيره — وهو
        // منعُ صلاحية لا نطاقٌ ناقص. ولا يُتجاهَل الطلب بصمت فيُكتب في معهدٍ آخر.
        if ($institute === null || ! $this->user->canAccessInstitute($institute)) {
            throw new AuthorizationException('لا يعمل هذا الحساب في المعهد المطلوب.');
        }

        return $institute;
    }

    private function home(): ?Institute
    {
        $instituteId = $this->user->homeInstituteId();

        return $instituteId === null ? null : Institute::find($instituteId);
    }

    /**
     * حاملُ الدور العابر بلا ترويسة ولا سجلّ: أوّلُ معهدٍ فعّال — وله أن يبدّل.
     */
    private function globalFallback(): ?Institute
    {
        if (! $this->user->hasGlobalRole()) {
            return null;
        }

        return Institute::query()->where('is_active', true)->orderBy('id')->first();
    }

    /**
     * ترويسةُ الطلب الجاري — نظيرُ قراءة PanelScope للجلسة، فيستوي كلُّ من يستدعي
     * ApiScope::for() في السطح الواحد بلا أن يُمرّر أحدٌ المعهدَ يدوياً وينساه آخر.
     */
    private static function requestedUuid(): ?string
    {
        if (! App::bound('request')) {
            return null;
        }

        $header = App::make('request')->header(self::HEADER);

        return is_string($header) ? $header : null;
    }
}
