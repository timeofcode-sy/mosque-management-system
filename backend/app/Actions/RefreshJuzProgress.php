<?php

namespace App\Actions;

use App\Enums\CurriculumType;
use App\Enums\ProgressStatus;
use App\Models\CurriculumItem;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\User;
use App\Support\Quran;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;

/**
 * نسبة كل جزء من آياته المحفوظة: الآيات المحفوظة ضمن حدّي الجزء ÷ آيات الجزء كلها.
 *
 * يُستدعى بعد كل تسميع يُسجَّل أو يُحذف، وبعد تعديل جزء يدوياً. الجزء الذي اكتملت
 * آياته يصير «محفوظاً» بنفسه، وينتظر سبر الأستاذ (score). أما «محفوظ» المعلَّم يدوياً
 * فيبقى كما هو — هو مصدرٌ للتغطية لا نتيجةٌ لها — ولا يُرفع إلا من نافذة الجزء.
 */
class RefreshJuzProgress
{
    public function __construct(private readonly BuildStudentMemorizedMap $memorized) {}

    public function handle(Student $student, ?User $actor = null): void
    {
        $items = $this->juzItems($student);

        if ($items->isEmpty()) {
            return;
        }

        $map = $this->memorized->handle($student);
        $today = Carbon::today()->toDateString();

        // `withTrashed`: قيد unique(student_id, curriculum_item_id) يشمل المحذوف، فالصفّ
        // المحذوف يُحيا ولا يُنشأ بجانبه صفٌّ يصطدم به.
        $rows = StudentCurriculumProgress::withTrashed()
            ->where('student_id', $student->id)
            ->whereIn('curriculum_item_id', $items->modelKeys())
            ->get()
            ->keyBy('curriculum_item_id');

        foreach ($items as $item) {
            $row = $rows->get($item->id);

            if ($row?->trashed()) {
                $row->deleted_at = null;
                $row->status = ProgressStatus::NotStarted;
                $row->percent = 0;
                $row->started_on = null;
                $row->score = null;
            }

            if ($row?->status === ProgressStatus::Memorized) {
                if ($row->percent !== 100) {
                    $row->update(['percent' => 100]);
                }

                continue;
            }

            $juz = (int) $item->juz();
            $total = Quran::juzAyahs($juz);
            $covered = BuildStudentMemorizedMap::coveredInJuz($map, $juz);

            if (($row === null || $row->isDirty('deleted_at')) && $covered === 0) {
                continue;
            }

            [$status, $percent] = match (true) {
                $covered >= $total => [ProgressStatus::Memorized, 100],
                $covered > 0 => [ProgressStatus::InProgress, min(99, max(1, intdiv($covered * 100, $total)))],
                default => [ProgressStatus::NotStarted, 0],
            };

            if ($row !== null && ! $row->isDirty('deleted_at') && $row->status === $status && $row->percent === $percent) {
                continue;
            }

            $row ??= new StudentCurriculumProgress([
                'student_id' => $student->id,
                'curriculum_item_id' => $item->id,
                'course_circle_id' => $student->activeEnrollment()?->course_circle_id,
                'teacher_id' => $actor?->teacher?->id,
            ]);

            $row->fill([
                'status' => $status,
                'percent' => $percent,
                'started_on' => $row->started_on?->toDateString() ?? ($status === ProgressStatus::NotStarted ? null : $today),
                'completed_on' => $status === ProgressStatus::Memorized ? $today : null,
                'achieved_on' => $status === ProgressStatus::NotStarted ? null : $today,
            ])->save();
        }
    }

    /**
     * بنود الأجزاء في مناهج القرآن المتاحة لمعهد الطالب (العامة ومناهجه الخاصة).
     *
     * @return Collection<int, CurriculumItem>
     */
    private function juzItems(Student $student): Collection
    {
        return CurriculumItem::query()
            ->whereHas('curriculum', fn ($query) => $query
                ->where('type', CurriculumType::Quran)
                ->where(fn ($query) => $query->whereNull('institute_id')->orWhere('institute_id', $student->institute_id)))
            ->with('curriculum')
            ->get()
            ->filter(fn (CurriculumItem $item) => $item->juz() !== null)
            ->values();
    }
}
