<?php

namespace App\Support;

use App\Models\AttendanceSession;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;

/**
 * دقائق تأخير الطالب — محسوبةً من بداية الدوام لا من لحظة فتح الجلسة.
 *
 * المرجع `shifts.starts_at` ثابتٌ ومعروف قبل أن يفتح أحدٌ شيئاً، فالرقم قابل للمقارنة
 * بين حلقةٍ وأخرى وبين جهازٍ وآخر. ولو قِيس من لحظة الفتح لصار «تأخيرُ الطالب» تابعاً
 * لتأخير أستاذه في فتح الجلسة، ولاختلف الرقمُ نفسه باختلاف من فتح.
 *
 * القرار مسجَّل في PHASE-5-STAGES.MD §0 البند 1، ونظيره في العميل
 * (packages/mousqe_core) يطبّق **نفس** هذه الصيغة ليعرض الأستاذ الرقم فوراً أوف-لاين
 * قبل أن يؤكّده الخادم.
 */
class LateMinutes
{
    /**
     * الدقائق، أو null حين لا مرجع يُقاس عليه.
     *
     * ثلاث حالات تعود null قصداً:
     * 1. لا دوام للحلقة (بيانات ناقصة) — لا مرجع أصلاً.
     * 2. زمن التسجيل من **يوم غير يوم الجلسة**: التفقّد الرجعي لتاريخٍ ماضٍ يُسجَّل اليوم،
     *    فالفرق بينه وبين بداية دوام ذلك اليوم أيامٌ لا دقائق. رقمٌ بلا معنى، وتركُه
     *    فارغاً أصدق من ملئه بعددٍ خيالي.
     * 3. الطالب وصل قبل بداية الدوام أو معها ⇒ صفر لا سالب.
     */
    public static function forSession(AttendanceSession $session, ?CarbonInterface $recordedAt = null): ?int
    {
        $startsAt = $session->courseCircle?->shift?->starts_at;

        if (blank($startsAt)) {
            return null;
        }

        $recordedAt = $recordedAt ?? now();

        $sessionDate = $session->session_date instanceof CarbonInterface
            ? $session->session_date->toDateString()
            : (string) $session->session_date;

        if ($recordedAt->toDateString() !== $sessionDate) {
            return null;
        }

        $start = Carbon::parse($sessionDate)->setTimeFromTimeString((string) $startsAt);

        return max(0, (int) floor($start->diffInMinutes($recordedAt, absolute: false)));
    }

    /**
     * الدقائق بعد خصم فترة السماح المضبوطة في إعدادات المعهد.
     *
     * فترة السماح صفرٌ افتراضاً، فيكون الرقمُ حرفياً «كم دقيقة بعد بداية الدوام». معهدٌ
     * يريد تسامحاً يضبطها فيصير الرقم «كم دقيقة تأخيرٍ غير مقبول».
     */
    public static function afterGrace(?int $minutes, int $graceMinutes): ?int
    {
        if ($minutes === null) {
            return null;
        }

        return max(0, $minutes - $graceMinutes);
    }
}
