<?php

namespace App\Actions;

use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use RuntimeException;

/**
 * قفل جلسة مكتملة نهائياً — بعده لا تعديل ولا إعادة فتح.
 */
class LockAttendanceSession
{
    public function handle(AttendanceSession $session): AttendanceSession
    {
        if ($session->status !== SessionStatus::Completed) {
            throw new RuntimeException('لا تُقفل إلا الجلسة المكتملة.');
        }

        $session->update(['status' => SessionStatus::Locked]);

        return $session->refresh();
    }
}
