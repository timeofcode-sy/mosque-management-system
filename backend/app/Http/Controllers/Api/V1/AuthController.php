<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\ApiScope;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
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
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'username' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:64'],
        ]);

        $user = User::query()
            ->where('username', $credentials['username'])
            ->orWhere(fn ($query) => $query->whereNotNull('email')->where('email', $credentials['username']))
            ->first();

        if ($user === null || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'username' => ['بيانات الدخول غير صحيحة.'],
            ]);
        }

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
