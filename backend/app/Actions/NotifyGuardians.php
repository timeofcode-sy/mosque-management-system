<?php

namespace App\Actions;

use App\Contracts\PushNotifier;
use App\Models\Device;
use App\Models\Student;
use App\Notifications\PushMessage;

/**
 * إشعارُ أولياء أمر طالبٍ بعينه — ✅ م.7.4.
 *
 * موضعٌ واحد يجمع أجهزةَ من يحقّ لهم أن يُبلَّغوا، فلا يعيد كلُّ فعلٍ بناءَ
 * الاستعلام. والأفعالُ التي تستدعيه لا تعرف Firebase ولا `devices`.
 */
class NotifyGuardians
{
    public function __construct(private PushNotifier $notifier) {}

    public function handle(Student $student, PushMessage $message): int
    {
        return $this->notifier->send($this->tokensFor($student), $message);
    }

    /**
     * توكناتُ أجهزةِ أولياء أمر هذا الطالب.
     *
     * 🔑 **من `devices` لا من عمودٍ على `guardians`**: للأب هاتفٌ ولزوجه آخر،
     * وقد يكون لكلٍّ منهما جهازان — والصفُّ لكل جهاز لا لكل شخص، فلا يمحو
     * تسجيلُ الثاني توكنَ الأوّل.
     *
     * **ومقصورةٌ على تطبيق ولي الأمر** (`app = guardian`): لولي الأمر أن يكون
     * أستاذاً في المعهد نفسِه بحسابٍ واحد، وإرسالُ إشعارِ أبٍ إلى تطبيق الأستاذ
     * يضع رسالةً عن ابنه في سطحٍ لم يُبنَ لها.
     *
     * @return array<int, string>
     */
    private function tokensFor(Student $student): array
    {
        $guardianUserIds = $student->guardians()
            ->whereNotNull('guardians.user_id')
            ->pluck('guardians.user_id');

        if ($guardianUserIds->isEmpty()) {
            return [];
        }

        return Device::query()
            ->whereIn('user_id', $guardianUserIds)
            ->where('app', 'guardian')
            ->pluck('fcm_token')
            ->all();
    }
}
