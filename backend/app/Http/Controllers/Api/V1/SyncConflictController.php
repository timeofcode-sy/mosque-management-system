<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\OverturnSyncConflict;
use App\Actions\ReviewSyncConflict;
use App\Http\Controllers\Controller;
use App\Http\Resources\V1\SyncConflictResource;
use App\Models\SyncConflict;
use App\Support\ApiScope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/**
 * التعارضات — رؤيةً وحكماً (conflicts.review).
 *
 * جدول sync_conflicts **لا يُزامَن** ([SYNC-PROTOCOL.md §7])، فلا يصل الديسكتوبَ في
 * sync/pull ولا يمكن أن يصله: هو أثرُ الدفعة لا بيانَ المعهد. ولذلك نقطةُ قراءةٍ
 * مباشرة — وهي الاستثناء الوحيد الذي يقرأ فيه الديسكتوب من الخادم لا من مخزنه.
 *
 * والحكمُ متّصلٌ بطبعه فلا طابورَ له: من يقلب حكماً ينتظر نتيجته، ولا معنى لأن
 * يُصفّ قرارٌ في جهازٍ أوف-لاين على تعارضٍ قد يكون حُسم من جهازٍ آخر.
 */
class SyncConflictController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['nullable', 'in:pending,reviewed,all'],
        ]);

        $status = $validated['status'] ?? 'pending';

        $conflicts = $this->scoped($request)
            ->with('reviewedBy:id,first_name,last_name')
            ->when($status === 'pending', fn (Builder $query) => $query->whereNull('resolved_at'))
            ->when($status === 'reviewed', fn (Builder $query) => $query->whereNotNull('resolved_at'))
            ->latest('id')
            ->limit(200)
            ->get();

        return response()->json(['data' => SyncConflictResource::collection($conflicts)]);
    }

    /**
     * الحكم: «اعتمِد قيمة الجهاز» (قلبٌ عبر TakeAttendance فتصل الأجهزةَ في سحبها
     * التالي) أو «أبقِ قيمة الخادم» (ختمٌ بلا كتابة).
     */
    public function resolve(
        Request $request,
        string $uuid,
        OverturnSyncConflict $overturn,
        ReviewSyncConflict $review,
    ): JsonResponse {
        $validated = $request->validate([
            'decision' => ['required', 'in:client_wins,server_wins'],
        ]);

        $conflict = $this->scoped($request)->where('uuid', $uuid)->firstOrFail();

        try {
            $validated['decision'] === 'client_wins'
                ? $overturn->handle($conflict, $request->user())
                : $review->handle($conflict, $request->user());
        } catch (RuntimeException $exception) {
            // الرفضُ المتوقَّع جلسةٌ مقفلة — TakeAttendance ترفضها ولو بـ amend.
            // رسالتُها تُعرض كما هي بدل 500 صامت أمام من ينتظر نتيجة قراره.
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        return response()->json(['data' => new SyncConflictResource($conflict->refresh())]);
    }

    /**
     * الحصر بالمعهد العامل — والمبرمج يعبره كما في شاشة اللوحة: التعارضات أداةُ
     * تشخيصٍ عنده، وصفوفُ ما قبل هجرةِ institute_id بلا معهد فلا يراها غيرُه.
     *
     * @return Builder<SyncConflict>
     */
    private function scoped(Request $request): Builder
    {
        $user = $request->user();
        $institute = ApiScope::for($user)->institute();

        return SyncConflict::query()
            ->unless($user->can('system.debug'), fn (Builder $query) => $query->where('institute_id', $institute->id));
    }
}
