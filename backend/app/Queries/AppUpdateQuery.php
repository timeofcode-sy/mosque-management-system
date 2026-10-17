<?php

namespace App\Queries;

use App\Enums\AppTarget;
use App\Models\AppInstall;
use App\Models\AppRelease;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;

/**
 * هل لهذه النسخة تحديث؟ وما بلغه كلُّ هدفٍ من الأجهزة؟
 *
 * 🔑 **الإلزامُ يُحسب من كل ما فات الجهاز لا من الأخير وحده**: جهازٌ على البناء 3، والبناءُ 4
 * إلزاميّ (أصلح خللاً في المزامنة) والبناءُ 5 اختياريّ — يُعرض عليه 5 **إلزامياً**، لأن تخطّيه
 * يتركه على ما فرض 4 تركَه. فمن نشر إصداراً إلزامياً لا يحتاج أن يعيد الإلزام في كل ما بعده.
 */
class AppUpdateQuery
{
    /** نافذةُ «الأجهزة النشطة» في شاشة المبرمج: ما سأل عن التحديث في آخر ثلاثين يوماً. */
    public const ACTIVE_DAYS = 30;

    /** أقصى ما يُعرض من سجلّ التغييرات لجهازٍ فاتته إصداراتٌ كثيرة. */
    public const MAX_CHANGES = 10;

    /**
     * @return array<string, mixed>|null
     */
    public function check(AppTarget $target, int $currentBuild): ?array
    {
        /** @var Collection<int, AppRelease> $newer */
        $newer = AppRelease::query()
            ->published()
            ->forTarget($target)
            ->where('build_number', '>', $currentBuild)
            ->orderByDesc('build_number')
            ->get();

        $latest = $newer->first();

        if ($latest === null) {
            return null;
        }

        return [
            'uuid' => $latest->uuid,
            'version' => $latest->version,
            'build_number' => $latest->build_number,
            'title' => $latest->title,
            'mandatory' => $newer->contains('is_mandatory', true),
            'published_at' => $latest->published_at?->toIso8601String(),
            'file_name' => $latest->file_name,
            'size' => $latest->file_size,
            'sha256' => $latest->sha256,
            // رابطٌ خارجي يُتبع كما هو؛ والملفُّ المرفوع يُطلب من الخادم الذي سأله التطبيق
            // (`download_path` نسبةً إلى عنوان الـ API) — فلا يتعلّق بعنوانٍ لا يبلغه جهازٌ على
            // خادمٍ محلّي.
            'download_url' => $latest->hasFile() ? null : $latest->external_url,
            'download_path' => "app-updates/{$latest->uuid}/download",
            'changes' => $newer->take(self::MAX_CHANGES)->map(fn (AppRelease $release): array => [
                'version' => $release->version,
                'build_number' => $release->build_number,
                'title' => $release->title,
                'mandatory' => $release->is_mandatory,
                'notes' => $release->noteLines(),
                'published_at' => $release->published_at?->toIso8601String(),
            ])->values()->all(),
        ];
    }

    /**
     * يحفظ ما أبلغ به الجهاز عن نسخته — صفٌّ واحدٌ لكل جهازٍ وهدف يتجدّد.
     */
    public function recordInstall(string $deviceUuid, AppTarget $target, int $build, ?string $version): void
    {
        AppInstall::query()->updateOrCreate(
            ['device_uuid' => $deviceUuid, 'target' => $target->value],
            ['build_number' => $build, 'version' => $version, 'last_checked_at' => now()],
        );
    }

    /**
     * لكل هدف: آخرُ إصدارٍ منشور، والأجهزةُ النشطة موزّعةً على أرقام البناء.
     *
     * @return array<string, array{latest: ?AppRelease, active: int, upToDate: int, builds: array<int, array{build: int, version: ?string, devices: int}>}>
     */
    public function overview(?Carbon $since = null): array
    {
        $since ??= now()->subDays(self::ACTIVE_DAYS);

        $installs = AppInstall::query()
            ->where('last_checked_at', '>=', $since)
            ->selectRaw('target, build_number, max(version) as version, count(*) as devices')
            ->groupBy('target', 'build_number')
            ->orderByDesc('build_number')
            ->get()
            ->groupBy(fn (AppInstall $row) => $row->target->value);

        $overview = [];

        foreach (AppTarget::cases() as $target) {
            $latest = AppRelease::query()->published()->forTarget($target)->orderByDesc('build_number')->first();

            $builds = $installs->get($target->value, collect())->map(fn (AppInstall $row): array => [
                'build' => $row->build_number,
                'version' => $row->version,
                'devices' => (int) $row->getAttribute('devices'),
            ])->values()->all();

            $current = array_filter($builds, fn (array $row) => $latest !== null && $row['build'] >= $latest->build_number);

            $overview[$target->value] = [
                'latest' => $latest,
                'active' => array_sum(array_column($builds, 'devices')),
                'upToDate' => array_sum(array_column($current, 'devices')),
                'builds' => $builds,
            ];
        }

        return $overview;
    }
}
