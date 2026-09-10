<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\User;
use App\Notifications\PushMessage;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * إغلاق جلسة التفقّد وإعادة حساب إحصاء الحلقة وترتيبها في دوامها.
 *
 * الحساب يجري متزامناً لا في طابور: الشاشة تعرض النسبة والترتيب فور الإغلاق،
 * وكلفته استعلاماتٌ معدودة على نطاق دوامٍ واحد في يومٍ واحد.
 * للحساب الشامل بأثر رجعي هناك الأمر mousqe:recalculate-stats.
 */
class CompleteAttendanceSession
{
    public function __construct(
        private RecalculateCircleStats $recalculate,
        private NotifyGuardians $notify,
    ) {}

    public function handle(AttendanceSession $session, ?User $takenBy = null): AttendanceSession
    {
        $wasCompleted = $session->status === SessionStatus::Completed;

        if ($session->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة أصلاً.');
        }

        DB::transaction(function () use ($session, $takenBy): void {
            $session->update([
                'status' => SessionStatus::Completed,
                'taken_by' => $takenBy?->id ?? $session->taken_by,
                'completed_at' => now(),
            ]);
        });

        $session->refresh()->loadMissing('courseCircle');

        $this->recalculate->handle(
            $session->courseCircle->shift_id,
            $session->session_date->toDateString(),
        );

        if (! $wasCompleted) {
            $this->announceAbsences($session);
        }

        return $session->refresh();
    }

    /**
     * إشعارُ أولياء الأمور بغياب أبنائهم — ✅ م.7.4.
     *
     * ## 🔑 عند **الإغلاق** لا عند كل كتابة
     *
     * `TakeAttendance` يُستدعى في كل ضغطة، وحالةُ الطالب تتبدّل قبل أن تستقرّ:
     * أستاذٌ يعلّم غائباً ثم يصل الطالبُ متأخّراً بعد دقيقة فيصحّحها. ولو أُشعر
     * عند الكتابة لَوصل الأبَ «غاب ابنُك» ثم لا يصله شيءٌ يصحّحه — **إنذارٌ كاذب
     * لا سبيل إلى سحبه**. والإغلاقُ هو اللحظة التي يقول فيها الأستاذ إن الكشف
     * انتهى.
     *
     * وهو تطبيقٌ لقاعدة م.6.6 نفسِها في سياقٍ آخر: **ما لم يستقرّ لا يُعلَن**.
     *
     * ## ولا يُعاد الإشعارُ على جلسةٍ مكتملة
     *
     * إكمالُ المكتملة يقع في التصحيح الرجعي وفي إعادة دفع عمليةٍ من الطابور
     * (`op_uuid` يمنع التكرار في `sync/push`، ولا يمنعه من اللوحة). و[$wasCompleted]
     * يجعل الإشعار أثراً لانتقالٍ لا لحالة.
     *
     * ## والفشلُ لا يُسقط الإغلاق
     *
     * الإشعارُ أثرٌ جانبيٌّ لفعلٍ نجح — والقناةُ نفسُها لا ترمي
     * ([PushNotifier](../Contracts/PushNotifier.php))، فالجلسةُ تُغلق وإحصاؤها
     * يُحسب سواءٌ وصل الإشعار أم لا.
     */
    private function announceAbsences(AttendanceSession $session): void
    {
        $absences = $session->attendances()
            ->where('status', AttendanceStatus::Absent)
            ->with('student')
            ->get();

        $date = $session->session_date->toDateString();

        foreach ($absences as $attendance) {
            $student = $attendance->student;

            if ($student === null) {
                continue;
            }

            $this->notify->handle($student, PushMessage::absenceRecorded(
                $student->full_name,
                $date,
                $student->uuid,
            ));
        }
    }
}
