<?php

namespace App\Actions;

use App\Enums\AppTarget;
use App\Models\AppRelease;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/**
 * يحفظ إصداراً ويُبقي ملفَّه على قرصٍ خاص — تحديثاتُ التطبيقات.
 *
 * الملفُّ المرفوع يُحسب حجمُه وبصمتُه (SHA-256) هنا مرّةً، فيتحقّق التطبيقُ بعد التنزيل أن ما
 * وصله هو ما رُفع بايتاً ببايت قبل أن يعرضه على المثبّت. والرابطُ الخارجي بلا بصمة: لا يُنزَّل
 * إلى الخادم ليُحسب، والتطبيقُ يكتفي معه بالحجم الذي يرسله المصدر.
 *
 * ملفٌّ يُستبدل، أو إصدارٌ يتحوّل إلى رابطٍ خارجي، يُحذف ملفُّه القديم — لا يبقى على القرص ما
 * لا يشير إليه صفّ.
 */
class SaveAppRelease
{
    /**
     * @param  array{target: string, version: string, build_number: int|string, title?: string|null, notes?: string|null, is_mandatory?: bool, external_url?: string|null, published_at?: mixed}  $attributes
     */
    public function handle(array $attributes, ?UploadedFile $file = null, ?User $author = null, ?AppRelease $existing = null): AppRelease
    {
        $target = AppTarget::from($attributes['target']);
        $disk = Storage::disk(AppRelease::DISK);

        $payload = [
            'target' => $target,
            'version' => trim($attributes['version']),
            'build_number' => (int) $attributes['build_number'],
            'title' => blank($attributes['title'] ?? null) ? null : trim((string) $attributes['title']),
            'notes' => blank($attributes['notes'] ?? null) ? null : trim((string) $attributes['notes']),
            'is_mandatory' => (bool) ($attributes['is_mandatory'] ?? false),
            'published_at' => $attributes['published_at'] ?? null,
        ];

        $staleFile = null;

        if ($file !== null) {
            $name = "nuzuln-{$target->value}-{$payload['version']}-b{$payload['build_number']}.{$target->extension()}";
            $name = preg_replace('/[^A-Za-z0-9._-]+/', '-', $name) ?? $name;

            $path = $file->storeAs(AppRelease::DIRECTORY."/{$target->value}", $name, AppRelease::DISK);

            $payload += [
                'file_path' => $path,
                'file_name' => $name,
                'file_size' => $disk->size($path),
                'sha256' => hash_file('sha256', $disk->path($path)),
                'external_url' => null,
            ];

            if ($existing?->file_path !== null && $existing->file_path !== $path) {
                $staleFile = $existing->file_path;
            }
        } elseif (! blank($attributes['external_url'] ?? null)) {
            $payload += [
                'external_url' => trim((string) $attributes['external_url']),
                'file_path' => null,
                'file_name' => null,
                'file_size' => null,
                'sha256' => null,
            ];

            $staleFile = $existing?->file_path;
        }

        if ($existing !== null) {
            $existing->update($payload);
            $release = $existing->refresh();
        } else {
            $release = AppRelease::create([...$payload, 'created_by' => $author?->id]);
        }

        if ($staleFile !== null) {
            $disk->delete($staleFile);
        }

        return $release;
    }

    /**
     * يحذف الإصدارَ وملفَّه معاً.
     */
    public function delete(AppRelease $release): void
    {
        if ($release->file_path !== null) {
            Storage::disk(AppRelease::DISK)->delete($release->file_path);
        }

        $release->delete();
    }
}
