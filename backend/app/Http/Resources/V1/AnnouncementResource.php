<?php

namespace App\Http\Resources\V1;

use App\Models\Announcement;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * إعلانٌ منشور كما يقرؤه الطالب — ✅ م.8.1.
 *
 * **ولا `scope_ids` في الخرج**: النطاقُ يُرشَّح في الخادم، ومعرّفاتُ الحلقات
 * الأخرى المشمولة بالإعلان ليست من شأن قارئه — بل هي بالضبط ما بُنيت هذه
 * المرحلة لئلّا يصل جهازَه ([PHASE-8-STAGES.MD §1.1](../../../../docs/PHASE-8-STAGES.MD)).
 *
 * @mixin Announcement
 */
class AnnouncementResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'title' => $this->title,
            'body' => $this->body,
            // «لمن وُجِّه» لا «لمن وُجِّه بالضبط»: يعرف الطالبُ أن الإعلانَ لحلقته
            // أو للمعهد كلِّه، فيقدّر أهميّتَه بلا أن يعرف بقيّةَ المشمولين.
            'scope' => $this->scope,
            'published_at' => $this->published_at,
        ];
    }
}
