<?php

namespace App\Contracts;

use App\Notifications\PushMessage;

/**
 * قناةُ الإشعار الفوري — ✅ م.7.4.
 *
 * 🔑 **واجهةٌ لا استدعاءٌ مباشر لـkreait**: الأفعالُ التي تُشعر (تسجيلُ غياب، البتُّ
 * في إذن) لا تعرف Firebase ولا تحمل بيانات اعتماد، ولا تنكسر حين لا يكون في
 * المعهد حسابُ إشعاراتٍ أصلاً. وهي نفسُ القاعدة التي حُفظ بها مكانُ الواتساب في
 * [PLAN.md §11](../../../docs/PLAN.md): «`MessageDriver` خلف واجهة».
 *
 * ولها تنفيذان: [\App\Notifications\FcmPushNotifier] حين تُضبط بيانات الاعتماد،
 * و[\App\Notifications\NullPushNotifier] حين لا تُضبط — فالنظامُ يعمل كاملاً بلا
 * حساب Firebase، وينقصه **الفوريةُ لا الوظيفة**.
 */
interface PushNotifier
{
    /**
     * يُرسل الرسالةَ إلى الأجهزة المعطاة، ويعيد **عدد ما وصل**.
     *
     * ولا يرمي عند فشل الإرسال: الإشعارُ أثرٌ جانبيٌّ لفعلٍ نجح — أستاذٌ سجّل
     * غياباً، ومشرفٌ بتّ في إذن. وإسقاطُ الفعل لأن الإشعار لم يصل يقلب الأولوية.
     *
     * @param  array<int, string>  $tokens
     */
    public function send(array $tokens, PushMessage $message): int;
}
