<?php

namespace App\Actions;

use App\Enums\ProgressStatus;
use App\Models\CurriculumItem;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\User;
use App\Support\PointsSettings;
use Illuminate\Support\Carbon;
use RuntimeException;

/**
 * تحديث إنجاز الطالب في بند منهج (متن، أربعون نبوية، جزء قرآني).
 *
 * النقاط تُشتقّ من النسبة × عدّاد البند (meta.hadiths أو meta.abyat) × معامل النوع،
 * ثم تُجمَّد في الصف: صفُّ التقدّم حالةٌ واحدة لكل بند، فإعادةُ الحساب عند كل حفظ
 * تعطي المجموع الصحيح للبند دون تكرار، وتغييرُ الإعدادات لاحقاً لا يمسّ ما مضى.
 *
 * الجزء القرآني يختلف: لا «متقَن» فيه — «محفوظ» يكفي، ودرجةُ سبره في score. ونسبتُه
 * لا تُدخَل بل تُشتقّ من آياته المسمَّعة (RefreshJuzProgress)، فما لم يُعلَّم محفوظاً
 * يُعاد حسابه بعد الحفظ.
 */
class SaveStudentCurriculumProgress
{
    public function __construct(private readonly RefreshJuzProgress $juzProgress) {}

    /**
     * @param  array{status: string, percent?: int|string|null, score?: int|string|null, notes?: string|null}  $data
     */
    public function handle(Student $student, CurriculumItem $item, array $data, ?User $actor = null): StudentCurriculumProgress
    {
        $status = ProgressStatus::tryFrom((string) $data['status']);

        if ($status === null) {
            throw new RuntimeException('حالة الإنجاز غير معروفة.');
        }

        $item->loadMissing('curriculum.institute');

        $isJuz = $item->juz() !== null;

        if ($isJuz && $status === ProgressStatus::Mastered) {
            $status = ProgressStatus::Memorized;
        }

        $percent = $this->percentFor($status, $data['percent'] ?? null);
        $today = Carbon::today()->toDateString();

        $points = PointsSettings::for($item->curriculum->institute ?? $student->institute)
            ->progressPoints($item, $percent);

        $existing = StudentCurriculumProgress::query()
            ->where('student_id', $student->id)
            ->where('curriculum_item_id', $item->id)
            ->first();

        $progress = StudentCurriculumProgress::updateOrCreate(
            ['student_id' => $student->id, 'curriculum_item_id' => $item->id],
            [
                'course_circle_id' => $student->activeEnrollment()?->course_circle_id,
                'status' => $status,
                'percent' => $percent,
                'score' => blank($data['score'] ?? null) ? null : (int) $data['score'],
                'notes' => blank($data['notes'] ?? null) ? null : $data['notes'],
                'points' => $points,
                'started_on' => $existing?->started_on?->toDateString()
                    ?? ($status === ProgressStatus::NotStarted ? null : $today),
                'completed_on' => $this->isComplete($status)
                    ? ($this->isComplete($existing?->status) ? $existing->completed_on?->toDateString() : null) ?? $today
                    : null,
                'achieved_on' => $status === ProgressStatus::NotStarted ? null : $today,
                'teacher_id' => $actor?->teacher?->id,
            ],
        );

        if ($isJuz && $status !== ProgressStatus::Memorized) {
            $this->juzProgress->handle($student, $actor);
            $progress->refresh();
        }

        return $progress;
    }

    /**
     * تاريخ الإتمام يبقى على أوّل يومٍ اكتمل فيه البند: تسجيل درجة السبر لاحقاً لا يزحزحه.
     */
    private function isComplete(?ProgressStatus $status): bool
    {
        return in_array($status, [ProgressStatus::Memorized, ProgressStatus::Mastered], true);
    }

    /**
     * الحالة تحكم النسبة في طرفيها: «لم يبدأ» صفرٌ دائماً، و«متقَن» مئةٌ دائماً،
     * فلا يبقى صفٌّ متناقض يقول «محفوظ 0%».
     */
    private function percentFor(ProgressStatus $status, int|string|null $percent): int
    {
        return match ($status) {
            ProgressStatus::NotStarted => 0,
            ProgressStatus::Memorized, ProgressStatus::Mastered => 100,
            ProgressStatus::InProgress => min(100, max(1, (int) $percent)),
        };
    }
}
