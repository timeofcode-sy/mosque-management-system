<?php

namespace App\Actions;

use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\User;
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
    public function __construct(private RecalculateCircleStats $recalculate) {}

    public function handle(AttendanceSession $session, ?User $takenBy = null): AttendanceSession
    {
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

        return $session->refresh();
    }
}
