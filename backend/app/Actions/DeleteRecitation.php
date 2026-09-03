<?php

namespace App\Actions;

use App\Enums\SessionStatus;
use App\Models\MemorizationLog;
use RuntimeException;

/**
 * حذف تسميع مسجَّل — بنفس حراسة القفل التي تحمي التفقّد.
 */
class DeleteRecitation
{
    public function handle(MemorizationLog $log): void
    {
        if ($log->attendanceSession?->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        $log->delete();
    }
}
