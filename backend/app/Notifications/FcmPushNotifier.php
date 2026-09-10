<?php

namespace App\Notifications;

use App\Contracts\PushNotifier;
use App\Models\Device;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Throwable;

/**
 * الإرسالُ الفعلي عبر FCM — ✅ م.7.4، ويُربَط حين تُضبط `FIREBASE_CREDENTIALS`.
 *
 * **وهو الموضعُ الوحيد في النظام كلِّه الذي يعرف kreait**، فتبديلُ المزوّد لاحقاً
 * تبديلُ صنفٍ واحد لا مطاردةُ استدعاءاتٍ في الأفعال.
 */
class FcmPushNotifier implements PushNotifier
{
    public function __construct(private Messaging $messaging) {}

    public function send(array $tokens, PushMessage $message): int
    {
        $tokens = array_values(array_unique(array_filter($tokens)));

        if ($tokens === []) {
            return 0;
        }

        $cloudMessage = CloudMessage::new()
            ->withNotification(Notification::create($message->title, $message->body))
            ->withData($message->data);

        try {
            $report = $this->messaging->sendMulticast($cloudMessage, $tokens);
        } catch (Throwable $error) {
            // لا يُرمى: الإشعارُ أثرٌ جانبيٌّ لفعلٍ نجح، وإسقاطُ تسجيلِ غيابٍ لأن
            // FCM لم يستجب يقلب الأولوية.
            Log::warning('تعذّر إرسال إشعار FCM.', ['error' => $error->getMessage()]);

            return 0;
        }

        $this->forgetDeadTokens([...$report->invalidTokens(), ...$report->unknownTokens()]);

        return $report->successes()->count();
    }

    /**
     * 🔑 **التوكن الميت يُحذف لا يُعاد إليه**: هاتفٌ أُلغي تثبيتُ التطبيق منه يبقى
     * صفُّه في `devices` إلى الأبد، فتُحمَّل كلُّ دفعةٍ بتوكناتٍ يردّها FCM. وهو
     * نموٌّ صامت — لا خطأ يُرمى ولا رقمَ ينقص.
     *
     * @param  array<int, string>  $dead
     */
    private function forgetDeadTokens(array $dead): void
    {
        if ($dead === []) {
            return;
        }

        Device::query()->whereIn('fcm_token', $dead)->delete();
    }
}
