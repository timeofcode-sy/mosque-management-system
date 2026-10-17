<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AppTarget;
use App\Http\Controllers\Controller;
use App\Models\AppRelease;
use App\Queries\AppUpdateQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * تحديثاتُ التطبيقات — نقطتان **بلا توكن**.
 *
 * التطبيقُ يسأل قبل الدخول أيضاً: تحديثٌ إلزاميّ يصلح خللاً في الدخول نفسِه لا يصحّ أن ينتظر
 * دخولاً لا ينجح. وما يُكشف هنا لا يخصّ أحداً: رقمُ نسخةٍ وسجلُّ تغييراتها وملفٌّ هو التطبيقُ
 * نفسُه الذي يحمله كلُّ مستخدم.
 */
class AppUpdateController extends Controller
{
    public function check(Request $request, AppUpdateQuery $updates): JsonResponse
    {
        $validated = $request->validate([
            'target' => ['required', Rule::enum(AppTarget::class)],
            'build' => ['required', 'integer', 'min:0'],
            'version' => ['nullable', 'string', 'max:32'],
            'device' => ['nullable', 'uuid'],
        ]);

        $target = AppTarget::from($validated['target']);
        $build = (int) $validated['build'];

        if (! blank($validated['device'] ?? null)) {
            $updates->recordInstall($validated['device'], $target, $build, $validated['version'] ?? null);
        }

        return response()->json([
            'target' => $target->value,
            'current_build' => $build,
            'update' => $updates->check($target, $build),
        ]);
    }

    /**
     * الملفُّ نفسُه، بدعم `Range` (BinaryFileResponse): تنزيلٌ انقطع على شبكة المسجد يُستأنف من
     * حيث وقف ولا يبدأ من الصفر. ويُعدّ التنزيلُ عند أول طلبٍ له لا عند كل استئناف.
     */
    public function download(Request $request, string $uuid): BinaryFileResponse|RedirectResponse
    {
        $release = AppRelease::query()->published()->where('uuid', $uuid)->firstOrFail();

        if (! $this->isResumed($request)) {
            $release->increment('downloads');
        }

        if (! $release->hasFile()) {
            abort_if(blank($release->external_url), 404);

            return redirect()->away($release->external_url);
        }

        $disk = Storage::disk(AppRelease::DISK);
        abort_unless($disk->exists($release->file_path), 404);

        return response()->download(
            $disk->path($release->file_path),
            $release->file_name,
            ['Content-Type' => $release->target->mimeType()],
        );
    }

    /**
     * طلبٌ يبدأ من غير البايت الأول استئنافٌ لتنزيلٍ عُدّ من قبل.
     */
    private function isResumed(Request $request): bool
    {
        $range = (string) $request->header('Range', '');

        return $range !== '' && ! str_starts_with($range, 'bytes=0-');
    }
}
