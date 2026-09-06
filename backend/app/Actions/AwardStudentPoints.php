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
     * @param  array{points: float|int|string, reason: string, note?: string|null, awarded_on?: string|null, course_circle_id?: int|null}  $data
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
        if ($editingId === null) {
            $attributes['awarded_by'] = $actor?->id;
        }

        return StudentPoint::updateOrCreate(['id' => $editingId], $attributes);
    }
}
