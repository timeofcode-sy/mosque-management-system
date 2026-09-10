<?php

namespace App\Http\Resources\V1;

use App\Models\AbsenceExcuse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * إذنُ غيابٍ مسبق كما يقرؤه مقدِّمُه — وليُّ الأمر في تطبيق المرحلة السابعة.
 *
 * ✅ م.7.1. وسببُ وجوده قرارُ 0.1 في [PHASE-7-STAGES.MD](../../../../docs/PHASE-7-STAGES.MD):
 * حالةُ الإذن كانت ستصل الجهازَ في تيّار `sync/pull`، ووليُّ الأمر خرج من
 * التيّار كلِّه فصار لها نقطتُها.
 *
 * @mixin AbsenceExcuse
 */
class AbsenceExcuseResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            // الابنُ في كل صفّ: لولي الأمر أكثرُ من ابنٍ في المعهد الواحد، وقائمةُ
            // أعذارٍ بلا اسمٍ تجعل الصفوفَ متشابهةً لا تُميَّز.
            'student_uuid' => $this->student?->uuid,
            'student_name' => $this->student?->full_name,
            'from_date' => $this->from_date?->toDateString(),
            'to_date' => $this->to_date?->toDateString(),
            'reason' => $this->reason,
            'status' => $this->status,
            // والحالةُ بنصِّها العربي من الـenum نفسِه لا من ترجمةٍ ثانية في Dart:
            // ثلاثُ حالاتٍ تُكتب مرّتين تفترقان عند إضافة رابعة.
            'status_label' => $this->status->label(),
            'reviewed_at' => $this->reviewed_at,
            // ملاحظةُ المراجِع هي **جوابُ الطاقم** على الطلب. بدونها يرى وليُّ
            // الأمر «مرفوض» بلا سبب، فيعاود التقديمَ بنفس الطلب.
            'review_note' => $this->review_note,
            'submitted_at' => $this->created_at,
        ];
    }
}
