<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\ApiScope;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;

/**
 * دخول تطبيقات فلاتر عبر توكن Sanctum شخصي — لا جلسة ولا كوكي، فالتطبيق يعمل أوف-لاين.
 *
 * الحقل username يقبل اسم المستخدم المولَّد أو البريد لمن له بريد: الطالب وولي
 * الأمر لا بريد لهما، وهما جمهور هذه التطبيقات.
 */
class AuthController extends Controller
{
    /**
     * ✅ م.9.1 — المحاولاتُ الخاطئة قبل قفل الاسم على هذا العنوان، ومدّةُ القفل.
     *
     * خمسٌ تسعُ من نسي محرفاً فأعاد، وتقصُر جداً عن تخمينٍ مجدٍ: خمسٌ كلَّ ربع
     * ساعة تعني عشرين محاولةً في الساعة، وكلمةُ المرور المولَّدة أبعدُ من ذلك
     * بمراتب.
     */
    private const MAX_ATTEMPTS = 5;

    private const LOCKOUT_SECONDS = 900;

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'username' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:64'],
        ]);

        $key = self::throttleKey($request, $credentials['username']);

        if (RateLimiter::tooManyAttempts($key, self::MAX_ATTEMPTS)) {
            throw ValidationException::withMessages([
                'username' => [self::waitMessage(RateLimiter::availableIn($key))],
            ])->status(429);
        }

        $user = User::query()
            ->where('username', $credentials['username'])
            ->orWhere(fn ($query) => $query->whereNotNull('email')->where('email', $credentials['username']))
            ->first();

        if ($user === null || ! Hash::check($credentials['password'], $user->password)) {
            RateLimiter::hit($key, self::LOCKOUT_SECONDS);

            throw ValidationException::withMessages([
                'username' => ['بيانات الدخول غير صحيحة.'],
            ]);
        }

        // 🔑 **النجاحُ يمسح العدّاد.** أبٌ يدخل من هاتفه ثم من هاتف زوجه ليس
        // مهاجماً، وعدٌّ لا يُمسح يقفل الحسابَ على صاحبه بلا أن يخطئ أحد.
        RateLimiter::clear($key);

        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'username' => ['هذا الحساب مقفل.'],
            ]);
        }

        $token = $user->createToken($credentials['device_name'])->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => self::identity($user),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'تم تسجيل الخروج.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(self::identity($request->user()));
    }

    /**
     * مفتاحُ العدّ: **الاسمُ والعنوانُ معاً** لا أحدُهما — ✅ م.9.1.
     *
     * العنوانُ وحده يقفل المعهدَ كلَّه: أجهزةُ المسجد خلف شبكةٍ واحدة تخرج بعنوانٍ
     * واحد، فخطأُ أستاذٍ في كلمته يمنع من خلفه أربعمئة طالب.
     *
     * والاسمُ وحده يفتح باباً آخر: من عرف اسمَ طالبٍ — وهو مطبوعٌ على بطاقته —
     * أقفل حسابَه عليه متى شاء بخمس محاولاتٍ خاطئة. حرمانٌ لا اختراقاً، لكنه ضرر.
     *
     * فباجتماعهما يُقفَل **الحسابُ على المهاجم** ويبقى مفتوحاً لصاحبه من جهازه.
     * والسقفُ العريض على العنوان وحده يبقى في `throttle:login`، لأن غايتَه أخرى:
     * منعُ إغراقٍ يستنزف المعالجَ بـbcrypt قبل أن يبلغ الطلبُ قاعدةَ البيانات
     * (`AppServiceProvider::configureRateLimits`).
     */
    private static function throttleKey(Request $request, string $username): string
    {
        return 'login|'.sha1(Str::lower($username).'|'.$request->ip());
    }

    /**
     * المدّةُ الباقية بصيغةٍ عربية سليمة — والتمييزُ يتبع العدد.
     */
    private static function waitMessage(int $seconds): string
    {
        $minutes = (int) ceil($seconds / 60);

        $wait = match (true) {
            $minutes <= 1 => 'دقيقة',
            $minutes === 2 => 'دقيقتين',
            $minutes <= 10 => "{$minutes} دقائق",
            default => "{$minutes} دقيقة",
        };

        return "حاولتَ مراراً. أعِد المحاولة بعد {$wait}.";
    }

    /**
     * هوية صاحب التوكن — واحدةٌ في login وme حتى لا تفترقا.
     *
     * 🔄 كانت roles تعود [] دائماً: المساران خارج institute.scope فمفتاح فريق spatie
     * غير مضبوط، وroles() في spatie 8 تُصفّي بالمعهد فلا تجد صفّاً. والحلّ ضبطُ النطاق
     * هنا **إن أمكن**: حسابٌ بلا معهد مرتبط (مدير معهد مثلاً) يبقى قادراً على الدخول
     * وتسجيل جهازه ثم يُرفض عند أول نقطة بيانات — وهو التمييز المقصود بين «كلمة مرور
     * خاطئة» و«حسابك غير مربوط بمعهد».
     *
     * @return array<string, mixed>
     */
    private static function identity(User $user): array
    {
        try {
            // بلا ترويسةِ معهد: الدخول يسبق اختيارَ المعهد، ولا يصحّ أن يفشل بسببه.
            ApiScope::for($user, '')->institute();
        } catch (AuthorizationException|RuntimeException) {
            // بلا معهد ⇒ بلا أدوار داخل معهد. الحقل يعود فارغاً لا الطلب يفشل.
        }

        return [
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'roles' => $user->getRoleNames(),
        ];
    }
}
