<?php

namespace App\Actions;

use App\Models\Announcement;
use App\Models\Institute;
use App\Models\User;

/**
 * كتابةُ إعلانٍ ونشرُه — ✅ م.8.1.
 *
 * فعلٌ لا كتابةٌ في الشاشة، كقاعدة المشروع: ما يُكتب من سطحين فأكثر يسكن
 * `app/Actions/`. وهو **الطرفُ الثاني** الذي كان ينقص جدولَ `announcements`
 * منذ م.1 ([PHASE-8-STAGES.MD §1.3](../../../docs/PHASE-8-STAGES.MD)) — فبلا
 * كاتبٍ تبقى نقطةُ القراءة وعداً لا يُنجَز.
 */
class PublishAnnouncement
{
    /**
     * @param  array{title: string, body: string, scope: string, scope_ids?: array<int, int>|null, published_at?: string|null}  $attributes
     */
    public function handle(Institute $institute, array $attributes, ?User $author = null, ?Announcement $existing = null): Announcement
    {
        $scope = $attributes['scope'] === 'circle' ? 'circle' : 'all';

        $payload = [
            'institute_id' => $institute->id,
            'title' => $attributes['title'],
            'body' => $attributes['body'],
            'scope' => $scope,
            // 🔑 نطاقٌ عامّ ⇒ **المعرّفاتُ تُمحى لا تُترك**: إعلانٌ حُوِّل من
            // «حلقة» إلى «الكلّ» وبقيت معرّفاتُه يبدو عامّاً ويحمل قائمةً تناقضه،
            // فيقرؤها من يبني عليها لاحقاً.
            'scope_ids' => $scope === 'circle' ? array_values($attributes['scope_ids'] ?? []) : null,
            'published_at' => $attributes['published_at'] ?? null,
        ];

        if ($existing !== null) {
            $existing->update($payload);

            return $existing->refresh();
        }

        return Announcement::create([...$payload, 'created_by' => $author?->id]);
    }
}
