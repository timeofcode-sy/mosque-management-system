<?php

namespace App\Queries;

use App\Models\MemorizationLog;
use App\Models\Student;
use App\Support\Quran;

/**
 * سجلُّ تسميع طالبٍ كما يقرؤه هو ووليُّ أمره: الأحدثُ أولاً، بأسماء السور والتقدير والنقاط —
 * تحت شريط الأجزاء في شاشة الحفظ، بدل نسبةٍ لكل جزء.
 */
class RecitationLogQuery
{
    public const LIMIT = 50;

    /**
     * @return array<int, array<string, mixed>>
     */
    public function forStudent(Student $student, int $limit = self::LIMIT): array
    {
        return MemorizationLog::query()
            ->where('student_id', $student->id)
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->limit($limit)
            ->get()
            ->map(fn (MemorizationLog $log): array => [
                'uuid' => $log->uuid,
                'date' => $log->date?->toDateString(),
                'type' => $log->type?->value,
                'type_label' => $log->type?->label(),
                'grade' => $log->grade?->value,
                'grade_label' => $log->grade?->label(),
                'from_surah_name' => $log->from_surah === null ? null : Quran::name($log->from_surah),
                'from_ayah' => $log->from_ayah,
                'to_surah_name' => $log->to_surah === null ? null : Quran::name($log->to_surah),
                'to_ayah' => $log->to_ayah,
                'lines' => (float) $log->lines,
                'points' => (float) $log->points,
                'notes' => $log->notes,
            ])
            ->all();
    }
}
