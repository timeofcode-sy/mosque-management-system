<?php

namespace App\Actions;

use App\Models\Student;
use App\Queries\StudentPointsQuery;

/**
 * مجموع نقاط طالب واحد ضمن مدى تواريخ، مقسّماً على مصادره الخمسة.
 *
 * للجداول التي تحتاج طلاباً كثيرين استعمل StudentPointsQuery::forCircle() — فهي تجمّع
 * في ثلاثة استعلامات بدل استعلامات بعدد الطلاب.
 */
class CalculateStudentPoints
{
    public function __construct(private readonly StudentPointsQuery $query) {}

    /**
     * @return array{quran: float, hadith: float, mutun: float, attendance: float, manual: float, total: float}
     */
    public function handle(Student $student, string $from, string $to): array
    {
        return $this->query->forStudent($student, $from, $to);
    }
}
