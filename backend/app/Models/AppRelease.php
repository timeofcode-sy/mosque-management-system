<?php

namespace App\Models;

use App\Concerns\HasUuid;
use App\Enums\AppTarget;
use Database\Factories\AppReleaseFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * إصدارٌ لتطبيقٍ ينشره المبرمج من شاشة «تحديثات التطبيقات»، ويسأل عنه التطبيقُ عند فتحه
 * (`GET /app-updates/check`). ليس جدولاً يُزامَن ولا يخصّ معهداً: النسخةُ واحدةٌ للنظام كلّه.
 */
#[Fillable([
    'target', 'version', 'build_number', 'title', 'notes', 'is_mandatory',
    'file_path', 'file_name', 'file_size', 'sha256', 'external_url', 'published_at', 'created_by',
])]
class AppRelease extends Model
{
    /** @use HasFactory<AppReleaseFactory> */
    use HasFactory, HasUuid;

    /** القرصُ الذي تُحفظ عليه الملفات — خاصٌّ لا يُخدَم إلا من نقطة التنزيل. */
    public const DISK = 'local';

    public const DIRECTORY = 'app-releases';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'target' => AppTarget::class,
            'build_number' => 'integer',
            'is_mandatory' => 'boolean',
            'file_size' => 'integer',
            'downloads' => 'integer',
            'published_at' => 'datetime',
        ];
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * @param  Builder<self>  $query
     */
    public function scopePublished(Builder $query): void
    {
        $query->whereNotNull('published_at')->where('published_at', '<=', now());
    }

    /**
     * @param  Builder<self>  $query
     */
    public function scopeForTarget(Builder $query, AppTarget $target): void
    {
        $query->where('target', $target->value);
    }

    public function isPublished(): bool
    {
        return $this->published_at !== null && $this->published_at->lte(now());
    }

    public function hasFile(): bool
    {
        return $this->file_path !== null;
    }

    /**
     * سجلُّ التغييرات سطراً سطراً: كلُّ سطرٍ غيرِ فارغٍ بندٌ، وتُنزع منه علامةُ قائمةٍ كتبها
     * الكاتب بيده («- » أو «• »).
     *
     * @return array<int, string>
     */
    public function noteLines(): array
    {
        return collect(preg_split('/\R/u', (string) $this->notes) ?: [])
            ->map(fn (string $line) => trim(preg_replace('/^\s*(?:[-*•·]|\d+[.)])\s*/u', '', $line) ?? ''))
            ->filter()
            ->values()
            ->all();
    }
}
