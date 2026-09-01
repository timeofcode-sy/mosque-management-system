<?php

namespace App\Http\Middleware;

use App\Support\ApiScope;
use Closure;
use Illuminate\Http\Request;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response;

/**
 * يحسم معهد المستخدم المصادَق بتوكن Sanctum ويضبط مفتاح الفريق في Spatie قبل أي
 * فحص صلاحية لاحق (middleware role:/permission:) — بلا هذا يفشل كل فحص صلاحية
 * على مستخدم أُسندت أدواره ضمن معهد بعينه.
 */
class SetApiInstituteScope
{
    public function handle(Request $request, Closure $next): Response
    {
        try {
            ApiScope::for($request->user())->institute();
        } catch (RuntimeException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        return $next($request);
    }
}
