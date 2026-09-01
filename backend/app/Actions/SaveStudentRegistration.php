<?php

namespace App\Actions;

use App\Enums\GuardianRelation;
use App\Enums\ProgressStatus;
use App\Models\CourseCircle;
use App\Models\CustomFieldValue;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Institute;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\StudentTrait;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * كتابة استمارة تسجيل الطالب كاملة في جدولة واحدة: الطالب، أولياء أمره، صفاته،
 * محفوظاته، واصفاته المخصّصة، وتسجيله في حلقة الدورة الجارية.
 */
class SaveStudentRegistration
{
    /**
     * @param  array<string, mixed>  $attributes  أعمدة جدول students
     * @param  array<string, array{full_name?: ?string, occupation?: ?string, phone?: ?string}>  $guardians  مفتاحها صلة القرابة
     * @param  array<int, int>  $traitIds
     * @param  array<int, int>  $memorizedItemIds  بنود المناهج التي أتمّها الطالب
     * @param  array<int, mixed>  $customFieldValues  مفتاحها معرّف الواصفة
     */
    public function handle(
        Institute $institute,
        array $attributes,
        ?Student $student = null,
        array $guardians = [],
        array $traitIds = [],
        array $memorizedItemIds = [],
        array $customFieldValues = [],
        ?int $courseCircleId = null,
    ): Student {
        return DB::transaction(function () use (
            $institute, $attributes, $student, $guardians, $traitIds, $memorizedItemIds, $customFieldValues, $courseCircleId
        ): Student {
            $student ??= new Student;
            $student->fill([...$attributes, 'institute_id' => $institute->id]);
            $student->save();

            $this->syncGuardians($institute, $student, $guardians);
            $this->syncTraits($student, $traitIds);
            $this->syncMemorizedItems($student, $memorizedItemIds);
            $this->syncCustomFieldValues($student, $customFieldValues);
            $this->enrollIfRequested($student, $courseCircleId);

            return $student->refresh();
        });
    }

    /**
     * @param  array<string, array{full_name?: ?string, occupation?: ?string, phone?: ?string}>  $guardians
     */
    private function syncGuardians(Institute $institute, Student $student, array $guardians): void
    {
        foreach ($guardians as $relation => $data) {
            $fullName = trim((string) ($data['full_name'] ?? ''));

            if ($fullName === '') {
                continue;
            }

            $existing = $student->guardians()->wherePivot('relation', $relation)->first();

            $guardian = $existing
                ? tap($existing)->update([
                    'full_name' => $fullName,
                    'occupation' => $data['occupation'] ?? null,
                    'phone' => $data['phone'] ?? null,
                ])
                : Guardian::create([
                    'institute_id' => $institute->id,
                    'full_name' => $fullName,
                    'occupation' => $data['occupation'] ?? null,
                    'phone' => $data['phone'] ?? null,
                ]);

            if ($existing === null) {
                GuardianStudent::create([
                    'guardian_id' => $guardian->id,
                    'student_id' => $student->id,
                    'relation' => $relation,
                    'is_primary' => $relation === GuardianRelation::Father->value,
                ]);
            }
        }
    }

    /**
     * جدولا الربط يحملان uuid إلزامياً للمزامنة، فالكتابة تمرّ بنموذج الربط لا بـ attach/sync.
     *
     * @param  array<int, int>  $traitIds
     */
    private function syncTraits(Student $student, array $traitIds): void
    {
        $traitIds = array_map('intval', $traitIds);
        $current = StudentTrait::query()->where('student_id', $student->id)->pluck('trait_id')->all();

        StudentTrait::query()
            ->where('student_id', $student->id)
            ->whereNotIn('trait_id', $traitIds ?: [0])
            ->delete();

        foreach (array_diff($traitIds, $current) as $traitId) {
            StudentTrait::create(['student_id' => $student->id, 'trait_id' => $traitId]);
        }
    }

    /**
     * البند المختار يصير «محفوظاً» ما لم يكن «متقَناً» أصلاً، والبند المُزال يعود «لم يبدأ»
     * بدل حذف السجل — فتبقى ملاحظات الأستاذ ودرجاته السابقة.
     *
     * @param  array<int, int>  $memorizedItemIds
     */
    private function syncMemorizedItems(Student $student, array $memorizedItemIds): void
    {
        $memorizedItemIds = array_map('intval', $memorizedItemIds);

        foreach ($memorizedItemIds as $itemId) {
            $progress = StudentCurriculumProgress::firstOrNew([
                'student_id' => $student->id,
                'curriculum_item_id' => $itemId,
            ]);

            if ($progress->status !== ProgressStatus::Mastered) {
                $progress->status = ProgressStatus::Memorized;
                $progress->completed_on ??= Carbon::today()->toDateString();
                $progress->save();
            }
        }

        StudentCurriculumProgress::query()
            ->where('student_id', $student->id)
            ->whereNotIn('curriculum_item_id', $memorizedItemIds ?: [0])
            ->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->update(['status' => ProgressStatus::NotStarted, 'completed_on' => null]);
    }

    /**
     * @param  array<int, mixed>  $customFieldValues
     */
    private function syncCustomFieldValues(Student $student, array $customFieldValues): void
    {
        foreach ($customFieldValues as $customFieldId => $value) {
            CustomFieldValue::updateOrCreate(
                [
                    'custom_field_id' => (int) $customFieldId,
                    'entity_type' => $student->getMorphClass(),
                    'entity_id' => $student->id,
                ],
                ['value' => $value],
            );
        }
    }

    private function enrollIfRequested(Student $student, ?int $courseCircleId): void
    {
        if ($courseCircleId === null) {
            return;
        }

        $courseCircle = CourseCircle::find($courseCircleId);

        if ($courseCircle === null) {
            return;
        }

        try {
            app(EnrollStudent::class)->handle($student, $courseCircle);
        } catch (RuntimeException) {
            /** الطالب مسجَّل أصلاً في هذه الدورة — التسجيل يُدار من شاشة الحلقة. */
        }
    }
}
