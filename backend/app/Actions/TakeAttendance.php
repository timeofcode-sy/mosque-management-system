<?php

namespace App\Actions;

use App\Enums\AttendanceStatus;
use App\Enums\NotePolarity;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\User;
use App\Support\AttendanceSettings;
use App\Support\LateMinutes;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * كتابة حالات التفقّد لجلسة قائمة.
 *
 * الجلسة المقفلة لا تُعدَّل إطلاقاً. والمكتملة لا تُعدَّل إلا بتعديل صريح ($amend)
 * تحرسه الصلاحية attendance.amend في الواجهة — فالتصحيح الرجعي فعلٌ مقصود لا سهو.
 */
class TakeAttendance
{
    /**
     * @param  array<int, array{status?: string, late_minutes?: int|string|null, note?: string|null, note_polarity?: string|null, recorded_at?: string|null}>  $rows  مفهرسة بمعرّف الطالب؛ recorded_at اختياري يستعمله الدفع أوف-لاين ليبقى زمن الحدث الحقيقي كما وقع على الجهاز، لا وقت وصوله للخادم
     */
    public function handle(AttendanceSession $session, array $rows, ?User $recordedBy = null, bool $amend = false): AttendanceSession
    {
        $this->guard($session, $amend);

        $grace = AttendanceSettings::for($session->courseCircle?->circle?->institute)->lateGraceMinutes();

        return DB::transaction(function () use ($session, $rows, $recordedBy, $grace): AttendanceSession {
            $enrollmentIds = $session->attendances()->pluck('enrollment_id', 'student_id');

            foreach ($rows as $studentId => $row) {
                $status = AttendanceStatus::tryFrom((string) ($row['status'] ?? ''));

                if ($status === null) {
                    continue;
                }

                $recordedAt = blank($row['recorded_at'] ?? null) ? now() : Carbon::parse($row['recorded_at']);

                Attendance::updateOrCreate(
                    ['attendance_session_id' => $session->id, 'student_id' => (int) $studentId],
                    [
                        'enrollment_id' => $enrollmentIds[(int) $studentId] ?? null,
                        'status' => $status,
                        'late_minutes' => $status === AttendanceStatus::Late
                            ? $this->lateMinutes($session, $row, $recordedAt, $grace)
                            : null,
                        'note' => blank($row['note'] ?? null) ? null : $row['note'],
                        'note_polarity' => blank($row['note'] ?? null)
                            ? null
                            : NotePolarity::tryFrom((string) ($row['note_polarity'] ?? '')),
                        'recorded_by' => $recordedBy?->id,
                        'recorded_at' => $recordedAt,
                    ],
                );
            }

            return $session->refresh();
        });
    }

    /**
     * دقائق التأخير: ما أرسله المستدعي إن أرسل، وإلا فمحسوبةً من بداية الدوام.
     *
     * الحساب هنا لا في الشاشة، فيستوي مصدرُ الكتابة: لوحةُ المشرف وتطبيقُ الأستاذ
     * ودفعةُ المزامنة تعطي الرقم نفسه لنفس الحدث. والقيمة المرسَلة صراحةً هي الحاكمة
     * دائماً — الحالةُ قرارُ الأستاذ والرقمُ تلقائي، لكن تصحيحَه اليدوي يبقى مسموحاً
     * (PHASE-5-STAGES.MD §0 البند 2).
     *
     * @param  array<string, mixed>  $row
     */
    private function lateMinutes(AttendanceSession $session, array $row, CarbonInterface $recordedAt, int $grace): int
    {
        if (! blank($row['late_minutes'] ?? null)) {
            return max(0, (int) $row['late_minutes']);
        }

        return LateMinutes::afterGrace(LateMinutes::forSession($session, $recordedAt), $grace) ?? 0;
    }

    private function guard(AttendanceSession $session, bool $amend): void
    {
        if ($session->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        if ($session->status === SessionStatus::Completed && ! $amend) {
            throw new RuntimeException('الجلسة مكتملة — أعد فتحها قبل التعديل.');
        }
    }
}
