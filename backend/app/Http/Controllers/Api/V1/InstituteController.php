<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Institute;
use App\Support\ApiScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * المعاهد التي يحقّ لصاحب التوكن أن يعمل فيها — مصدرُ مبدّل المعاهد في الديسكتوب.
 *
 * لا تبديلَ بحالةٍ على الخادم: الجهاز يختار معهداً من هذه القائمة ثم يُرفق uuid في
 * ترويسة X-Institute مع كل طلب لاحق (ApiScope::HEADER). فالخادمُ يبقى بلا جلسة،
 * وجهازان لنفس الحساب يعملان في معهدين مختلفين في آنٍ واحد بلا أن يزيح أحدُهما الآخر.
 */
class InstituteController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $scope = ApiScope::for($request->user());
        $current = $scope->institute();

        return response()->json([
            'current' => $current->uuid,
            'data' => $scope->institutes()->map(fn (Institute $institute): array => [
                'uuid' => $institute->uuid,
                'name' => $institute->name,
                'logo_path' => $institute->logo_path,
                'is_active' => (bool) $institute->is_active,
            ])->all(),
        ]);
    }
}
