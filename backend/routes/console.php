<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

/**
 * النسخُ الاحتياطي الليلي — ✅ م.9.2.
 *
 * الثانيةُ ليلاً: بعد أن يُغلق أستاذُ آخرِ دوامٍ جلستَه بساعات، وقبل أن يفتح
 * أوّلُهم غداً. والنسخُ لا يقفل الكتابة أصلاً (`--single-transaction` و
 * `VACUUM INTO`)، لكنّ ساعةَ الهدوء تبقى أرخصَ على القرص.
 *
 * و`withoutOverlapping` لأن `keep_days` قد يطول ومجلَّدُ الرفوعات قد يكبر:
 * نسخةٌ لم تنتهِ بعدُ لا يصحّ أن تبدأ فوقها نسخةُ الليلة التالية.
 *
 * 🔴 **وهذا الجدولُ لا يعمل وحده.** لارافيل لا يوقظ نفسَه: يلزم الخادمَ سطرٌ
 * واحد في cron يستدعي `schedule:run` كلَّ دقيقة. وبدونه لا يُكتب شيءٌ ولا يُرفع
 * خطأ — بندٌ في دليل النشر حين تُحسم الاستضافة.
 */
Schedule::command('mousqe:backup')
    ->dailyAt('02:00')
    ->withoutOverlapping()
    ->onFailure(fn () => logger()->error('فشلت النسخةُ الاحتياطية الليلية.'));
