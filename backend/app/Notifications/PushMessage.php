<?php

namespace App\Notifications;

/**
 * حمولةُ إشعارٍ فوري — عنوانٌ ونصٌّ وبياناتُ توجيهٍ يقرؤها التطبيق.
 *
 * [$data] **نصوصٌ كلُّها**: FCM لا ينقل إلا نصوصاً في حقل `data`، والأرقامُ تصل
 * نصوصاً عند الطرف الآخر — فتُكتب نصوصاً ههنا بدل أن تُحوَّل صامتةً.
 */
class PushMessage
{
    /**
     * @param  array<string, string>  $data
     */
    public function __construct(
        public readonly string $title,
        public readonly string $body,
        public readonly array $data = [],
    ) {}

    /**
     * غيابُ ابنٍ سُجِّل اليوم.
     */
    public static function absenceRecorded(string $studentName, string $sessionDate, string $studentUuid): self
    {
        return new self(
            title: 'تسجيل غياب',
            body: "سُجِّل غيابُ $studentName في حلقة اليوم.",
            data: ['type' => 'absence', 'student_uuid' => $studentUuid, 'session_date' => $sessionDate],
        );
    }

    /**
     * البتُّ في إذنٍ قدّمه وليُّ الأمر — **وتكملةُ الدائرة التي بدأها هو**.
     */
    public static function excuseReviewed(string $studentName, bool $approved, string $excuseUuid): self
    {
        return new self(
            title: $approved ? 'قُبل إذن الغياب' : 'رُفض إذن الغياب',
            body: $approved
                ? "قُبل إذنُ غياب $studentName."
                : "رُفض إذنُ غياب $studentName — افتح التطبيق لقراءة ملاحظة المعهد.",
            data: ['type' => 'excuse', 'excuse_uuid' => $excuseUuid, 'approved' => $approved ? '1' : '0'],
        );
    }
}
