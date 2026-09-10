<?php

namespace App\Http\Resources\V1;

use App\Models\StudentCurriculumProgress;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * بندٌ من محفوظات الطالب — جزءٌ قرآني أو متنٌ أو بابُ حديث.
 *
 * ✅ م.7.1، وكان **مؤجَّلاً إلى «ما قبل م.8»**: `/student/me/progress` كانت
 * النقطةَ الوحيدة في النظام كلِّه التي تعيد نموذجاً خاماً — كلَّ أعمدة الجدول
 * بمفاتيحها الداخلية (`student_id`، `curriculum_item_id`، `teacher_id`) وبشكلٍ
 * غيرِ مثبَّتٍ بعقد ([API.md §8](../../../../docs/API.md)). فتحُ نقطةِ تقدُّمٍ
 * ثانية لولي الأمر كان سيضاعف الشكلَ غيرَ المثبَّت بدل أن يثبّته.
 *
 * **ولا مفتاحَ داخلياً في الخرج**: العميلُ يشير بالـ`uuid` وحده كما في بقيّة
 * الموارد ([API.md §6](../../../../docs/API.md)).
 *
 * @mixin StudentCurriculumProgress
 */
class ProgressResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'item_name' => $this->curriculumItem?->name,
            'item_code' => $this->curriculumItem?->code,
            'sort_order' => $this->curriculumItem?->sort_order,
            'status' => $this->status,
            'status_label' => $this->status->label(),
            'percent' => $this->percent,
            'score' => $this->score,
            // النقاطُ رقمٌ لا نصّ: العمود decimal:2 فيصل نصّاً "12.00" في JSON،
            // وقارئُه في Dart يتوقّع num. القاعدةُ نفسُها في [API.md §3.4].
            'points' => $this->points === null ? null : (float) $this->points,
            'started_on' => $this->started_on?->toDateString(),
            'completed_on' => $this->completed_on?->toDateString(),
            'achieved_on' => $this->achieved_on?->toDateString(),
            'notes' => $this->notes,
        ];
    }
}
