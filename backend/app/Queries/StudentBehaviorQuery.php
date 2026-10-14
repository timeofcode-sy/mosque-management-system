<?php

namespace App\Queries;

use App\Enums\NotePolarity;
use App\Enums\PointReason;
use App\Models\Attendance;
use App\Models\Student;
use App\Models\StudentPoint;

/**
 * الجانب السلوكي لطالب: ملاحظاتُ الأساتذة في التفقّد (ثناءٌ أو تنبيهٌ أو ملاحظةٌ مجرّدة)، وصفاتُه
 * الشخصية، ونقاطُ السلوك. يقرؤه وليُّ الأمر والطالب من الخادم، والأستاذ يبنيه من drift بالقواعد
 * نفسها (`StudentBehavior` في mousqe_core).
 */
class StudentBehaviorQuery
{
    /**
     * @return array{
     *     summary: array{positive: int, negative: int, neutral: int, behavior_points: float},
     *     notes: list<array{date: ?string, polarity: ?string, note: string, circle: ?string}>,
     *     traits: list<array{name: string, polarity: string, note: ?string}>,
     *     points: list<array{date: ?string, points: float, note: ?string}>,
     * }
     */
    public function for(Student $student, int $limit = 50): array
    {
        $notes = Attendance::query()
            ->where('student_id', $student->id)
            ->whereNotNull('note')
            ->where('note', '!=', '')
            ->with('attendanceSession.courseCircle.circle')
            ->get()
            ->sortByDesc(fn (Attendance $attendance) => $attendance->attendanceSession?->session_date?->toDateString() ?? '')
            ->values();

        $points = StudentPoint::query()
            ->where('student_id', $student->id)
            ->where('reason', PointReason::Behavior)
            ->orderByDesc('awarded_on')
            ->get();

        $count = fn (?NotePolarity $polarity) => $notes->filter(fn (Attendance $attendance) => $attendance->note_polarity === $polarity)->count();

        return [
            'summary' => [
                'positive' => $count(NotePolarity::Positive),
                'negative' => $count(NotePolarity::Negative),
                'neutral' => $count(null),
                'behavior_points' => round((float) $points->sum('points'), 2),
            ],
            'notes' => $notes->take($limit)->map(fn (Attendance $attendance) => [
                'date' => $attendance->attendanceSession?->session_date?->toDateString(),
                'polarity' => $attendance->note_polarity?->value,
                'note' => (string) $attendance->note,
                'circle' => $attendance->attendanceSession?->courseCircle?->circle?->name,
            ])->all(),
            'traits' => $student->personalTraits()->orderBy('sort_order')->get()->map(fn ($trait) => [
                'name' => $trait->name,
                'polarity' => $trait->polarity->value,
                'note' => $trait->pivot->note,
            ])->all(),
            'points' => $points->take($limit)->map(fn (StudentPoint $point) => [
                'date' => $point->awarded_on?->toDateString(),
                'points' => (float) $point->points,
                'note' => $point->note,
            ])->all(),
        ];
    }
}
