<?php

namespace App\Notifications;

use App\Contracts\PushNotifier;
use Illuminate\Support\Facades\Log;

/**
 * قناةٌ صامتة — تُربَط حين **لا** تُضبط بيانات اعتماد Firebase.
 *
 * 🔑 وهي ما يجعل المرحلة السابعة تُسلَّم عاملةً بلا حساب Firebase: التطبيقُ يُفتح
 * فيرى وليُّ الأمر الغيابَ، والذي ينقصه أن يُبلَّغ به — **نقصٌ في الفورية لا في
 * الوظيفة** ([PHASE-7-STAGES.MD §0.2](../../../docs/PHASE-7-STAGES.MD)).
 *
 * وتكتب سطراً في السجل عند مستوى `debug` لا `warning`: غيابُ الحساب **حالةُ
 * إعدادٍ معلنة** لا عطبٌ يُنبَّه عليه في كل غياب يُسجَّل.
 */
class NullPushNotifier implements PushNotifier
{
    public function send(array $tokens, PushMessage $message): int
    {
        Log::debug('إشعارٌ لم يُرسَل — لا بيانات اعتماد Firebase مضبوطة.', [
            'title' => $message->title,
            'devices' => count($tokens),
        ]);

        return 0;
    }
}
