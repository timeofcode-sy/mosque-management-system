<?php

namespace App\Actions;

use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use RuntimeException;

/**
 * إعادة جلسة مكتملة إلى المسودّة لتصحيحها. المقفلة لا تُفتح — القفل قرار نهائي.
 */
class ReopenAttendanceSession
{
    public function handle(AttendanceSession $session): AttendanceSession
    {
        if ($session->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا يمكن إعادة فتحها.');
        }

        $session->update(['status' => SessionStatus::Draft, 'completed_at' => null]);

        return $session->refresh();
    }
}
