<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Actions\AssignUserRole;
use App\Actions\ChangeUserPassword;
use App\Actions\InviteUser;
use App\Actions\RevokeUserRole;
use App\Actions\ToggleUserActivation;
use App\Enums\PanelRole;
use App\Http\Controllers\Controller;
use App\Models\Institute;
use App\Models\User;
use App\Queries\CredentialQuery;
use App\Queries\UserAdminQuery;
use App\Support\ApiScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use RuntimeException;

/**
 * المستخدمون والأدوارُ وبياناتُ الدخول — سطحُ الإدارة في الـ API، ✅ م.6.2.
 *
 * **لماذا REST لا طابور؟** ([PHASE-6-STAGES.MD §3.1]) من يُنشئ حساباً ينتظر كلمةَ
 * المرور المولَّدة ليكتبها في بطاقة ويسلّمها؛ ولا معنى لطابورٍ أوف-لاين يحمل سرّاً
 * إلى وقتٍ لاحق. نظيرُ `POST /guardian/excuses` ([API.md §3.6]).
 *
 * **ولماذا نقطةُ قراءةٍ هنا وحدها؟** لأن `users` **خارج المزامنة عمداً**
 * ([SYNC-PROTOCOL.md §2]): حمولتُها بيانات دخول لا تُبثّ في تيّارٍ يقرؤه كل جهاز في
 * المعهد. فما لا يصل في `sync/pull` لا بدّ أن يُقرأ من نقطة.
 *
 * **والعنونةُ بـ`id` لا `uuid`** لنفس السبب: لا عمود `uuid` في `users` أصلاً، إذ
 * لا صفَّ منه يعبر تيّارَ التغييرات فيحتاج معرّفاً عالمياً.
 *
 * الحراسةُ كلُّها في الأفعال لا هنا: `AssignUserRole::assertAssignable` و
 * `outranks` تُطبَّق على السطحين معاً — لا يُسند أحدٌ دوراً أعلى من دوره، ولا
 * يطّلع مشرفٌ على كلمة مشرفٍ نظيره. والقوائمُ أدناه تُبنى منها كي لا يرى المستخدمُ
 * ما لا يملكه، لكنّ الرفض الحقيقي يقع في الفعل.
 */
class UserAdminController extends Controller
{
    /**
     * كتالوجُ الأدوار — ما يحقّ لهذا الحساب إسنادُه وما يحقّ له إنشاؤه.
     *
     * نقطةٌ صغيرة لكنها تمنع أكبرَ نسخٍ محتمل: بلا هذا كان على الديسكتوب أن ينسخ
     * `PanelRole` وهرمَه وتسمياتِه العربية إلى Dart، فيفترق السطحان عند أوّل تعديل
     * ([PHASE-6-STAGES.MD §0] القرار 3).
     */
    public function roles(Request $request): JsonResponse
    {
        $actor = $request->user();

        $map = fn (PanelRole $role): array => [
            'name' => $role->value,
            'label' => $role->label(),
            'is_global' => $role->isGlobal(),
            'rank' => $role->rank(),
        ];

        return response()->json([
            'assignable' => array_map($map, AssignUserRole::assignableRoles($actor)),
            'creatable' => array_map($map, AssignUserRole::creatableRoles($actor)),
        ]);
    }

    /**
     * مستخدمو المعهد العامل وأدوارُهم عبر المعاهد — القائمةُ نفسُها التي تعرضها
     * شاشةُ اللوحة (UserAdminQuery)، محصورةً بمعهدٍ واحد ما لم يُطلب غيرُه.
     */
    public function index(Request $request, UserAdminQuery $query): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['nullable', 'string', 'max:255'],
            'role' => ['nullable', Rule::in(PanelRole::names())],
            'scope' => ['nullable', 'in:institute,all'],
        ]);

        $institute = ApiScope::for($request->user())->institute();
        $scope = $validated['scope'] ?? 'institute';

        // «كلُّ المعاهد» لحاملِ الدور العابر وحده — وهو من يرى المعاهد كلَّها أصلاً.
        $instituteId = $scope === 'all' && $request->user()->hasGlobalRole() ? null : $institute->id;

        $users = $query->list($validated['q'] ?? '', $validated['role'] ?? '', $instituteId);
        $assignments = $query->roleAssignments($users->getCollection()->modelKeys());

        return response()->json([
            'data' => $users->getCollection()
                ->map(fn (User $user): array => $this->payload($user, $assignments->get($user->id, [])))
                ->all(),
            'meta' => [
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'total' => $users->total(),
            ],
        ]);
    }

    /**
     * إنشاءُ حسابٍ إداري — والردُّ يحمل كلمةَ المرور المولَّدة **مرّةً واحدة**.
     *
     * لا قناةَ بريد في المشروع، فالتسليمُ نسخٌ يدوي: من يُنشئ الحساب يطبع البطاقة
     * ويسلّمها. والنسخةُ تبقى في `generated_password` ليعيدها `GET /admin/credentials`
     * لمن يعلو صاحبَها رتبةً.
     */
    public function store(Request $request, InviteUser $inviteUser): JsonResponse
    {
        $creatable = array_map(fn (PanelRole $role): string => $role->value, AssignUserRole::creatableRoles($request->user()));

        $validated = $request->validate([
            'first_name' => ['required', 'string', 'max:255'],
            'last_name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:32'],
            'role' => ['required', Rule::in($creatable)],
            'institute_uuid' => ['nullable', 'uuid'],
        ]);

        $role = PanelRole::from($validated['role']);

        $result = $this->attempt(fn (): array => $inviteUser->handle(
            $request->user(),
            [
                'first_name' => $validated['first_name'],
                'last_name' => $validated['last_name'],
                'email' => $validated['email'] ?? null,
                'phone' => $validated['phone'] ?? null,
            ],
            $role,
            $role->isGlobal() ? null : $this->institute($request, $validated['institute_uuid'] ?? null),
        ));

        if ($result instanceof JsonResponse) {
            return $result;
        }

        return response()->json([
            'data' => $this->payload($result['user'], []),
            'credentials' => [
                'username' => $result['user']->username,
                'password' => $result['password'],
            ],
        ], 201);
    }

    /**
     * إسنادُ دورٍ لمستخدمٍ قائم داخل معهد (أو خارج المعاهد إن كان الدور عابراً).
     */
    public function assignRole(Request $request, User $user, AssignUserRole $assignRole): JsonResponse
    {
        $assignable = array_map(fn (PanelRole $role): string => $role->value, AssignUserRole::assignableRoles($request->user()));

        $validated = $request->validate([
            'role' => ['required', Rule::in($assignable)],
            'institute_uuid' => ['nullable', 'uuid'],
        ]);

        $role = PanelRole::from($validated['role']);

        $failure = $this->attempt(fn () => $assignRole->handle(
            $request->user(),
            $user,
            $role,
            $role->isGlobal() ? null : $this->institute($request, $validated['institute_uuid'] ?? null),
        ));

        return $failure instanceof JsonResponse ? $failure : $this->show($user);
    }

    public function revokeRole(Request $request, User $user, RevokeUserRole $revokeRole): JsonResponse
    {
        $validated = $request->validate([
            'role' => ['required', Rule::in(PanelRole::names())],
            'institute_uuid' => ['nullable', 'uuid'],
        ]);

        $role = PanelRole::from($validated['role']);

        $failure = $this->attempt(fn () => $revokeRole->handle(
            $request->user(),
            $user,
            $role,
            $role->isGlobal() ? null : $this->institute($request, $validated['institute_uuid'] ?? null),
        ));

        return $failure instanceof JsonResponse ? $failure : $this->show($user);
    }

    /**
     * تبديلُ كلمة مرور — بتوليد ثمانية أرقام أو بكلمةٍ يكتبها المشرف.
     */
    public function resetPassword(Request $request, User $user, ChangeUserPassword $changePassword): JsonResponse
    {
        $validated = $request->validate([
            'password' => ['nullable', 'string', 'min:8', 'max:64'],
        ]);

        $password = $this->attempt(fn (): string => $changePassword->handle(
            $request->user(),
            $user,
            $validated['password'] ?? null,
        ));

        if ($password instanceof JsonResponse) {
            return $password;
        }

        return response()->json([
            'credentials' => ['username' => $user->username, 'password' => $password],
        ]);
    }

    /**
     * إقفالُ حسابٍ أو فتحُه — والمقفلُ تسقط رموزُه عند أوّل طلب (EnsureUserIsActive).
     */
    public function activation(Request $request, User $user, ToggleUserActivation $toggle): JsonResponse
    {
        $validated = $request->validate(['is_active' => ['required', 'boolean']]);

        $failure = $this->attempt(fn () => $toggle->handle($request->user(), $user, (bool) $validated['is_active']));

        return $failure instanceof JsonResponse ? $failure : $this->show($user->refresh());
    }

    /**
     * بطاقاتُ الدخول جاهزةً للطباعة — خلف `credentials.export`.
     *
     * ثلاثةُ قيودٍ تحكم ما يُرى وهي في CredentialQuery لا هنا: المعهد، والرتبة
     * (لا يرى أحدٌ بيانات من يساويه أو يعلوه)، ووجودُ نسخةٍ مقروءة من الكلمة.
     */
    public function credentials(Request $request, CredentialQuery $query): JsonResponse
    {
        $validated = $request->validate([
            'role' => ['nullable', Rule::in(PanelRole::names())],
            'q' => ['nullable', 'string', 'max:255'],
        ]);

        $institute = ApiScope::for($request->user())->institute();

        return response()->json([
            'data' => $query->rows($institute, $request->user(), $validated['role'] ?? '', $validated['q'] ?? '')->all(),
        ]);
    }

    /**
     * الفعلُ محروسٌ بالرتبة والصلاحية، ورفضُه `RuntimeException` برسالةٍ عربية —
     * تُعاد 422 كما تُعاد رسالةُ التحقّق، لا 500 أمام من ينتظر نتيجة قراره.
     * نفسُ ما يفعله SyncConflictController منذ م.6.1.
     *
     * @template TValue
     *
     * @param  callable(): TValue  $callback
     * @return TValue|JsonResponse
     */
    private function attempt(callable $callback)
    {
        try {
            return $callback();
        } catch (RuntimeException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }
    }

    /**
     * المعهدُ المقصود بالإسناد: المطلوبُ في الجسم إن وصل — ويُتحقَّق أنه من معاهد
     * الفاعل — وإلا فالمعهدُ العامل. فلا يُسند مديرُ معهدٍ دوراً في معهدٍ غيرِه.
     */
    private function institute(Request $request, ?string $uuid): Institute
    {
        if (blank($uuid)) {
            return ApiScope::for($request->user())->institute();
        }

        return ApiScope::for($request->user(), $uuid)->institute();
    }

    private function show(User $user): JsonResponse
    {
        $assignments = app(UserAdminQuery::class)->roleAssignments([$user->id]);

        return response()->json(['data' => $this->payload($user, $assignments->get($user->id, []))]);
    }

    /**
     * ⚠️ بلا كلمة مرور: النسخةُ المقروءة تُعاد من نقطة البطاقات وحدها، وهي محصورةٌ
     * بالرتبة (CredentialQuery).
     *
     * @param  array<int, array{role: string, institute_id: int, institute: string|null}>  $assignments
     * @return array<string, mixed>
     */
    private function payload(User $user, array $assignments): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'phone' => $user->phone,
            'is_active' => (bool) $user->is_active,
            'roles' => array_map(fn (array $row): array => [
                'role' => $row['role'],
                'label' => PanelRole::labelOf($row['role']),
                'institute' => $row['institute'],
                'is_global' => $row['institute_id'] === User::GLOBAL_TEAM_ID,
            ], $assignments),
        ];
    }
}
