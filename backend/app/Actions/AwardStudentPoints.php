<?php

namespace App\Actions;

use App\Enums\PointReason;
use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\User;
use Illuminate\Support\Carbon;
use RuntimeException;

/**
 * منح نقاط تقديرية لطالب — موجبة (مشاركة، مسابقة) أو سالبة (مشاغبة).
 *
 * قد ترتبط بجلسة فتخضع لقفلها، وقد تستقلّ عنها فتُنسب إلى تاريخ وحده.
 */
class AwardStudentPoints
{
    /**
     * @param  array{uuid?: string|null, points: float|int|string, reason: string, note?: string|null, awarded_on?: string|null, course_circle_id?: int|null}  $data
     * @param  int|null  $editingId  منحة قائمة تُصحَّح بدل أن تُضاف ثانية
     */
    public function handle(Student $student, array $data, ?User $actor = null, ?AttendanceSession $session = null, ?int $editingId = null): StudentPoint
    {
        if ($session?->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        $reason = PointReason::tryFrom((string) $data['reason']);

        if ($reason === null) {
            throw new RuntimeException('سبب النقاط غير معروف.');
        }

        $points = round((float) $data['points'], 2);

        if ($points === 0.0) {
            throw new RuntimeException('لا معنى لمنح صفر نقطة.');
        }

        // 🔄 نظير ما في SaveRecitation: العميل أوف-لاين يولّد `uuid` المنحة، فيصحّحها
        // بإعادة إرسالها بنفس المعرّف — لا مفتاحَ أساسياً عنده يشير به إليها.
        $award = $this->resolve($data['uuid'] ?? null, $editingId);

        $attributes = [
            'student_id' => $student->id,
            'course_circle_id' => $data['course_circle_id'] ?? $session?->course_circle_id,
            'attendance_session_id' => $session?->id,
            'points' => $points,
            'reason' => $reason,
            'note' => blank($data['note'] ?? null) ? null : $data['note'],
            'awarded_on' => $data['awarded_on']
                ?? $session?->session_date?->toDateString()
                ?? Carbon::today()->toDateString(),
        ];

        // المانح يُثبَّت لحظة المنح: من صحّح القيمة لاحقاً لا يرث نسبتها إليه.
        if (! $award->exists) {
            $attributes['awarded_by'] = $actor?->id;
        }

        $award->fill($attributes)->save();

        return $award;
    }

    /**
     * المنحة التي يقصدها الحفظ: القائمة بمفتاحها أو بمعرّفها، أو منحةٌ جديدة تحمل
     * المعرّف الذي ولّده العميل.
     */
    private function resolve(?string $uuid, ?int $editingId): StudentPoint
    {
        if ($editingId !== null) {
            return StudentPoint::findOrFail($editingId);
        }

        if (blank($uuid)) {
            return new StudentPoint;
        }

        // `withTrashed`: قيد `unique(uuid)` يشمل المحذوف حذفاً ناعماً.
        $award = StudentPoint::withTrashed()->where('uuid', $uuid)->first();

        if ($award !== null) {
            $award->restore();

            return $award;
        }

        $fresh = new StudentPoint;
        $fresh->uuid = $uuid;

        return $fresh;
    }
}
