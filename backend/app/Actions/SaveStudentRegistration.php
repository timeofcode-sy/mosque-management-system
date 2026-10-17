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
    public function __construct(private readonly RefreshJuzProgress $juzProgress) {}

    /**
     * @param  array<string, mixed>  $attributes  أعمدة جدول students
     * @param  array<string, array{first_name?: ?string, family_name?: ?string, full_name?: ?string, occupation?: ?string, phone?: ?string}>  $guardians  مفتاحها صلة القرابة
     * @param  array<int, int>  $traitIds
     * @param  array<int, int>  $memorizedItemIds  بنود المناهج التي أتمّها الطالب
     * @param  array<int, mixed>  $customFieldValues  مفتاحها معرّف الواصفة
     * @param  array<string, int>  $siblingGuardianIds  أولياء أمر أخٍ مسجَّل أكّد المستخدم الأخوّة معه، مفتاحها صلة القرابة
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
        array $siblingGuardianIds = [],
    ): Student {
        return DB::transaction(function () use (
            $institute, $attributes, $student, $guardians, $traitIds, $memorizedItemIds, $customFieldValues, $courseCircleId, $siblingGuardianIds
        ): Student {
            $student ??= new Student;
            $student->fill([...$attributes, 'institute_id' => $institute->id]);
            $student->save();

            $this->syncGuardians($institute, $student, $guardians, $siblingGuardianIds);
            $this->syncTraits($student, $traitIds);
            $this->syncMemorizedItems($student, $memorizedItemIds);
            $this->syncCustomFieldValues($student, $customFieldValues);
            $this->enrollIfRequested($student, $courseCircleId);

            // الجزء المُزال من المحفوظات يعود إلى ما تقوله تسميعاته، لا إلى الصفر.
            $this->juzProgress->handle($student);

            return $student->refresh();
        });
    }

    /**
     * ولي الأمر سجلٌّ واحد يتشاركه الإخوة، فحسابه يرى أبناءه كلَّهم. لذا لا يُعاد تسمية
     * سجلٍّ مشترك من استمارة أحد الإخوة: تغيّرُ الاسم يعني أن لهذا الطالب ولياً آخر.
     *
     * الاسم يصل بقسميه (الاسم والكنية)، أو كاملاً من عميلٍ أقدم فيُقسم على أول فراغ.
     *
     * @param  array<string, array{first_name?: ?string, family_name?: ?string, full_name?: ?string, occupation?: ?string, phone?: ?string}>  $guardians
     * @param  array<string, int>  $siblingGuardianIds
     */
    private function syncGuardians(Institute $institute, Student $student, array $guardians, array $siblingGuardianIds): void
    {
        foreach ($guardians as $relation => $data) {
            [$firstName, $familyName] = array_key_exists('first_name', $data) || array_key_exists('family_name', $data)
                ? [Guardian::composeName($data['first_name'] ?? null), Guardian::composeName($data['family_name'] ?? null)]
                : Guardian::splitName($data['full_name'] ?? null);

            $fullName = Guardian::composeName($firstName, $familyName);

            if ($fullName === '') {
                continue;
            }

            $details = [
                'first_name' => $firstName ?: null,
                'family_name' => $familyName ?: null,
                'occupation' => $data['occupation'] ?? null,
                'phone' => $data['phone'] ?? null,
            ];

            $current = $student->guardians()->wherePivot('relation', $relation)->first();

            $sibling = isset($siblingGuardianIds[$relation])
                ? Guardian::query()->where('institute_id', $institute->id)->find($siblingGuardianIds[$relation])
                : null;

            if ($sibling !== null) {
                // ما تركته الاستمارة فارغاً يبقى على ما سُجِّل مع الأخ.
                $sibling->update(array_filter($details, fn ($value) => $value !== null));
                $this->link($student, $current, $sibling, $relation);

                continue;
            }

            if ($current !== null && ($current->full_name === $fullName || ! $this->sharedBeyond($current, $student))) {
                $current->update($details);

                continue;
            }

            $this->link($student, $current, Guardian::create([...$details, 'institute_id' => $institute->id]), $relation);
        }
    }

    private function sharedBeyond(Guardian $guardian, Student $student): bool
    {
        return GuardianStudent::query()
            ->where('guardian_id', $guardian->id)
            ->where('student_id', '!=', $student->id)
            ->exists();
    }

    /**
     * يستبدل ولي الأمر في صلة القرابة هذه. السجلّ القديم إن لم يبق له أبناء نسخةٌ مكرَّرة
     * فيُحذف حذفاً ليّناً، فيُقفل حسابه ولا يبقى في قوائم الدخول.
     */
    private function link(Student $student, ?Guardian $current, Guardian $guardian, string $relation): void
    {
        if ($current?->is($guardian)) {
            return;
        }

        if ($current !== null) {
            GuardianStudent::query()
                ->where('student_id', $student->id)
                ->where('guardian_id', $current->id)
                ->where('relation', $relation)
                ->get()
                ->each->delete();

            if (! GuardianStudent::query()->where('guardian_id', $current->id)->exists()) {
                $current->delete();
            }
        }

        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $student->id,
            'relation' => $relation,
            'is_primary' => $relation === GuardianRelation::Father->value,
        ]);
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
                $progress->percent = 100;
                $progress->completed_on ??= Carbon::today()->toDateString();
                $progress->save();
            }
        }

        StudentCurriculumProgress::query()
            ->where('student_id', $student->id)
            ->whereNotIn('curriculum_item_id', $memorizedItemIds ?: [0])
            ->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->update(['status' => ProgressStatus::NotStarted, 'percent' => 0, 'completed_on' => null]);
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
