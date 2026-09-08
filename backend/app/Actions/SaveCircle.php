<?php

namespace App\Actions;

use App\Models\Circle;
use App\Models\Institute;

/**
 * إنشاء حلقة أو تحريرها — هويّتُها الثابتة عبر الدورات لا تشغيلُها ضمن دورة،
 * وذاك فعلٌ ثانٍ (RunCircleInCourse).
 *
 * أُخرجت من شاشة الحلقات في م.6.2 ليستدعيها السطحان — [ARCHITECTURE.md §3].
 */
class SaveCircle
{
    /**
     * @param  array<string, mixed>  $attributes  name · level? · color? · sort_order? · is_active? · notes?
     */
    public function handle(Institute $institute, array $attributes, ?Circle $circle = null): Circle
    {
        $circle ??= new Circle;

        $circle->fill([...$attributes, 'institute_id' => $institute->id])->save();

        return $circle->refresh();
    }
}
