<?php

namespace App\Actions;

use App\Enums\SessionStatus;
use App\Models\StudentPoint;
use RuntimeException;

/**
 * حذف منحة نقاط مسجَّلة — نظير DeleteRecitation، وبنفس حراسة القفل.
 *
 * منحةٌ بلا جلسة لا قفل عليها: هي منسوبةٌ إلى تاريخٍ وحده (AwardStudentPoints).
 */
class DeleteStudentPoints
{
    public function handle(StudentPoint $award): void
    {
        if ($award->attendanceSession?->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }

        $award->delete();
    }
}
