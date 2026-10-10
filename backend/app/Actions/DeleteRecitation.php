<?php

namespace App\Actions;

use App\Enums\SessionStatus;
use App\Models\MemorizationLog;
use RuntimeException;

/**
 * حذف تسميع مسجَّل — بنفس حراسة القفل التي تحمي التفقّد، ثم إعادة حساب نسب الأجزاء.
 */
class DeleteRecitation
{
    public function __construct(private readonly RefreshJuzProgress $juzProgress) {}

    public function handle(MemorizationLog $log): void
    {
        if ($log->attendanceSession?->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        $log->delete();

        if ($log->student !== null) {
            $this->juzProgress->handle($log->student);
        }
    }
}
