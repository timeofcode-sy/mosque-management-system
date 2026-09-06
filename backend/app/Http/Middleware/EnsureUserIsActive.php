<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * يقطع الطريق على حسابٍ أُقفل بعد دخوله.
 *
 * فحصُ الدخول وحده لا يكفي: جلسةُ اللوحة تبقى قائمة ورمزُ Sanctum في التطبيق يبقى
 * صالحاً شهوراً، فطالبٌ انسحب اليوم يظلّ يقرأ بيانات معهده حتى ينتهي رمزُه.
 */
class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user === null || $user->is_active) {
            return $next($request);
        }

        if ($request->is('api/*')) {
            $user->currentAccessToken()?->delete();

            return response()->json(['message' => 'هذا الحساب مقفل.'], Response::HTTP_FORBIDDEN);
        }

        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login')->withErrors(['username' => 'هذا الحساب مقفل.']);
    }
}
