<?php

use App\Actions\SaveStudentRegistration;
use App\Concerns\InteractsWithInstitute;
use App\Enums\CustomFieldType;
use App\Enums\Gender;
use App\Enums\GuardianRelation;
use App\Enums\ProgressStatus;
use App\Enums\StudentStatus;
use App\Models\CourseCircle;
use App\Models\Curriculum;
use App\Models\CustomField;
use App\Models\PersonalTrait;
use App\Models\Student;
use App\Queries\StudentFormQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;
use Livewire\WithFileUploads;

new #[Title('استمارة تسجيل طالب')] class extends Component {
    use InteractsWithInstitute, WithFileUploads;

    public ?Student $student = null;

    /** بيانات التسجيل */
    public string $registration_no = '';

    public string $registration_date = '';

    public string $registration_date_hijri = '';

    public string $status = 'active';

    public $photo = null;

    /** البيانات الشخصية */
    public string $first_name = '';

    public string $father_name = '';

    public string $family_name = '';

    public string $birth_date = '';

    public string $birth_place = '';

    public string $gender = 'male';

    public string $national_id = '';

    public string $grade_level = '';

    public string $student_job = '';

    public string $phone = '';

    public string $permanent_address = '';

    public string $current_address = '';

    /** العائلة */
    public string $father_full_name = '';

    public string $father_occupation = '';

    public string $father_phone = '';

    public string $mother_full_name = '';

    public string $mother_occupation = '';

    public string $mother_phone = '';

    public string $family_members_count = '';

    /** الحالة الصحية والملاحظات */
    public string $student_health_status = '';

    public string $family_health_status = '';

    public string $notes = '';

    /**
     * @var array<int, string>
     */
    public array $traitIds = [];

    /**
     * @var array<int, string>
     */
    public array $memorizedItemIds = [];

    /**
     * @var array<int, mixed>
     */
    public array $customFields = [];

    public ?int $courseCircleId = null;

    public function mount(?Student $student = null): void
    {
        $this->requireInstitute();

        $this->registration_date = now()->toDateString();

        if ($student?->exists !== true) {
            return;
        }

        $this->student = $student->load('guardians', 'personalTraits', 'curriculumProgress', 'customFieldValues');

        $this->fillFromStudent($student);
    }

    private function fillFromStudent(Student $student): void
    {
        foreach ([
            'registration_no', 'registration_date_hijri', 'first_name', 'father_name', 'family_name',
            'birth_place', 'national_id', 'grade_level', 'student_job', 'phone',
            'permanent_address', 'current_address', 'student_health_status', 'family_health_status', 'notes',
        ] as $field) {
            $this->{$field} = (string) $student->{$field};
        }

        $this->registration_date = $student->registration_date?->toDateString() ?? '';
        $this->birth_date = $student->birth_date?->toDateString() ?? '';
        $this->gender = $student->gender->value;
        $this->status = $student->status->value;
        $this->family_members_count = (string) $student->family_members_count;

        $father = $student->father();
        $mother = $student->mother();

        $this->father_full_name = (string) $father?->full_name;
        $this->father_occupation = (string) $father?->occupation;
        $this->father_phone = (string) $father?->phone;
        $this->mother_full_name = (string) $mother?->full_name;
        $this->mother_occupation = (string) $mother?->occupation;
        $this->mother_phone = (string) $mother?->phone;

        $this->traitIds = $student->personalTraits->pluck('id')->map(fn (int $id) => (string) $id)->all();

        $this->memorizedItemIds = $student->curriculumProgress
            ->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->pluck('curriculum_item_id')
            ->map(fn (int $id) => (string) $id)
            ->all();

        $this->customFields = $student->customFieldValues
            ->mapWithKeys(fn ($value) => [$value->custom_field_id => $value->value])
            ->all();

        $this->courseCircleId = $student->activeEnrollment()?->course_circle_id;
    }

    private function query(): StudentFormQuery
    {
        return app(StudentFormQuery::class);
    }

    /**
     * @return Collection<int, PersonalTrait>
     */
    #[Computed]
    public function personalTraits(): Collection
    {
        return $this->query()->personalTraits($this->institute);
    }

    /**
     * @return Collection<int, Curriculum>
     */
    #[Computed]
    public function curricula(): Collection
    {
        return $this->query()->curricula($this->institute);
    }

    /**
     * @return Collection<int, CustomField>
     */
    #[Computed]
    public function customFieldDefinitions(): Collection
    {
        return $this->query()->customFieldDefinitions($this->institute);
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function courseCircles(): Collection
    {
        return $this->query()->courseCircles($this->currentCourse);
    }

    public function save(SaveStudentRegistration $saveStudentRegistration): void
    {
        $validated = $this->validate([
            'registration_no' => [
                'nullable', 'string', 'max:32',
                Rule::unique('students', 'registration_no')
                    ->where('institute_id', $this->institute->id)
                    ->ignore($this->student?->id),
            ],
            'registration_date' => ['nullable', 'date'],
            'registration_date_hijri' => ['nullable', 'string', 'max:24'],
            'status' => ['required', Rule::enum(StudentStatus::class)],
            'photo' => ['nullable', 'image', 'max:2048'],
            'first_name' => ['required', 'string', 'max:255'],
            'father_name' => ['required', 'string', 'max:255'],
            'family_name' => ['required', 'string', 'max:255'],
            'birth_date' => ['nullable', 'date', 'before:today'],
            'birth_place' => ['nullable', 'string', 'max:255'],
            'gender' => ['required', Rule::enum(Gender::class)],
            'national_id' => ['nullable', 'string', 'max:32'],
            'grade_level' => ['nullable', 'string', 'max:255'],
            'student_job' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:32'],
            'permanent_address' => ['nullable', 'string', 'max:255'],
            'current_address' => ['nullable', 'string', 'max:255'],
            'father_full_name' => ['nullable', 'string', 'max:255'],
            'father_occupation' => ['nullable', 'string', 'max:255'],
            'father_phone' => ['nullable', 'string', 'max:32'],
            'mother_full_name' => ['nullable', 'string', 'max:255'],
            'mother_occupation' => ['nullable', 'string', 'max:255'],
            'mother_phone' => ['nullable', 'string', 'max:32'],
            'family_members_count' => ['nullable', 'integer', 'min:1', 'max:60'],
            'student_health_status' => ['nullable', 'string'],
            'family_health_status' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
            'traitIds' => ['array'],
            'memorizedItemIds' => ['array'],
            'courseCircleId' => ['nullable', 'integer'],
        ], attributes: $this->validationAttributes());

        $attributes = collect($validated)->only([
            'registration_no', 'registration_date', 'registration_date_hijri', 'status',
            'first_name', 'father_name', 'family_name', 'birth_date', 'birth_place', 'gender',
            'national_id', 'grade_level', 'student_job', 'phone',
            'permanent_address', 'current_address', 'family_members_count',
            'student_health_status', 'family_health_status', 'notes',
        ])->map(fn ($value) => $value === '' ? null : $value)->all();

        if ($this->photo !== null) {
            $attributes['photo_path'] = $this->photo->store('students', 'public');
        }

        $student = $saveStudentRegistration->handle(
            institute: $this->institute,
            attributes: $attributes,
            student: $this->student,
            guardians: [
                GuardianRelation::Father->value => [
                    'full_name' => $this->father_full_name,
                    'occupation' => $this->father_occupation ?: null,
                    'phone' => $this->father_phone ?: null,
                ],
                GuardianRelation::Mother->value => [
                    'full_name' => $this->mother_full_name,
                    'occupation' => $this->mother_occupation ?: null,
                    'phone' => $this->mother_phone ?: null,
                ],
            ],
            traitIds: array_map('intval', $this->traitIds),
            memorizedItemIds: array_map('intval', $this->memorizedItemIds),
            customFieldValues: $this->customFields,
            courseCircleId: $this->courseCircleId,
        );

        Flux::toast(variant: 'success', text: 'حُفظت استمارة الطالب.');

        $this->redirect(route('students.show', $student), navigate: true);
    }

    /**
     * @return array<string, string>
     */
    private function validationAttributes(): array
    {
        return [
            'first_name' => 'اسم الطالب',
            'father_name' => 'اسم الأب',
            'family_name' => 'اسم العائلة',
            'registration_no' => 'رقم المعرف',
            'birth_date' => 'تاريخ الولادة',
            'traitIds' => 'الصفات',
            'memorizedItemIds' => 'المحفوظات',
            'courseCircleId' => 'الحلقة',
        ];
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header
        :heading="$student ? 'تعديل بيانات '.$student->full_name : 'استمارة تسجيل طالب'"
        subheading="البيانات الشخصية والعائلية والصحية والمحفوظات — كلها في استمارة واحدة"
    >
        <x-slot name="actions">
            <flux:button :href="route('students.index')" wire:navigate variant="ghost" icon="arrow-right">الطلاب</flux:button>
        </x-slot>
    </x-page-header>

    <form wire:submit="save" class="flex flex-col gap-6">
        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>بيانات التسجيل</flux:legend>

            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
                <flux:input wire:model="registration_no" label="رقم المعرف (البطاقة)" />
                <flux:input wire:model="registration_date" type="date" label="تاريخ التسجيل" />
                <flux:input wire:model="registration_date_hijri" label="التاريخ الهجري" placeholder="1447/03/12" />

                <flux:select wire:model="status" label="حالة الطالب">
                    @foreach (StudentStatus::options() as $value => $label)
                        <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                    @endforeach
                </flux:select>
            </div>

            <div class="mt-6">
                <x-image-upload
                    model="photo"
                    label="الصورة الشخصية"
                    shape="circle"
                    :existing-url="$student?->photo_path ? Storage::url($student->photo_path) : null"
                    hint="PNG أو JPG، حتى 2 ميغابايت"
                />
            </div>
        </flux:fieldset>

        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>البيانات الشخصية</flux:legend>

            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                <flux:input wire:model="first_name" label="اسم الطالب" required autofocus />
                <flux:input wire:model="father_name" label="اسم الأب" required />
                <flux:input wire:model="family_name" label="اسم العائلة" required />
                <flux:input wire:model="birth_date" type="date" label="تاريخ الولادة" />
                <flux:input wire:model="birth_place" label="مكان الولادة" />

                <flux:select wire:model="gender" label="الجنس">
                    @foreach (Gender::options() as $value => $label)
                        <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                    @endforeach
                </flux:select>

                <flux:input wire:model="national_id" label="الرقم الوطني" />
                <flux:input wire:model="grade_level" label="الصف الدراسي" />
                <flux:input wire:model="student_job" label="عمل الطالب أو مهنته" />
                <flux:input wire:model="phone" label="جوال الطالب" />
                <flux:input wire:model="permanent_address" label="العنوان الأساسي" />
                <flux:input wire:model="current_address" label="العنوان الحالي" />
            </div>
        </flux:fieldset>

        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>بيانات العائلة</flux:legend>

            <div class="grid gap-6 sm:grid-cols-3">
                <flux:input wire:model="father_full_name" label="اسم الأب الكامل" />
                <flux:input wire:model="father_occupation" label="عمل الأب" />
                <flux:input wire:model="father_phone" label="جوال الأب" />
                <flux:input wire:model="mother_full_name" label="اسم الأم" />
                <flux:input wire:model="mother_occupation" label="عمل الأم" />
                <flux:input wire:model="mother_phone" label="جوال الأم" />
            </div>

            <flux:input wire:model="family_members_count" type="number" min="1" label="عدد أفراد العائلة" class="mt-6 sm:max-w-xs" />
        </flux:fieldset>

        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>الوضع الصحي</flux:legend>

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:textarea wire:model="student_health_status" label="الوضع الصحي للطالب" rows="3" />
                <flux:textarea wire:model="family_health_status" label="الوضع الصحي للعائلة" rows="3" />
            </div>
        </flux:fieldset>

        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>الصفات الشخصية والسلوكية</flux:legend>

            <flux:checkbox.group wire:model="traitIds" class="grid gap-3 sm:grid-cols-3">
                @foreach ($this->personalTraits as $personalTrait)
                    <flux:checkbox value="{{ $personalTrait->id }}" label="{{ $personalTrait->name }}" />
                @endforeach
            </flux:checkbox.group>
        </flux:fieldset>

        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>المحفوظات</flux:legend>
            <flux:text class="mb-4">اختر ما أتمّه الطالب من بنود المناهج. المحدَّد يُسجَّل «محفوظاً»، والمُتقَن يبقى كما هو.</flux:text>

            <div class="flex flex-col gap-6">
                @foreach ($this->curricula as $curriculum)
                    <div wire:key="curriculum-{{ $curriculum->id }}">
                        <flux:heading size="sm">{{ $curriculum->name }}</flux:heading>

                        <flux:checkbox.group wire:model="memorizedItemIds" class="mt-3 grid gap-2 sm:grid-cols-3 lg:grid-cols-5">
                            @foreach ($curriculum->items as $item)
                                <flux:checkbox value="{{ $item->id }}" label="{{ $item->name }}" />
                            @endforeach
                        </flux:checkbox.group>
                    </div>
                @endforeach
            </div>
        </flux:fieldset>

        @if ($this->customFieldDefinitions->isNotEmpty())
            <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
                <flux:legend>الواصفات المخصّصة</flux:legend>

                <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                    @foreach ($this->customFieldDefinitions as $field)
                        <div wire:key="custom-field-{{ $field->id }}">
                            @switch($field->type)
                                @case(CustomFieldType::Textarea)
                                    <flux:textarea wire:model="customFields.{{ $field->id }}" :label="$field->label" rows="3" />
                                    @break
                                @case(CustomFieldType::Number)
                                    <flux:input wire:model="customFields.{{ $field->id }}" type="number" :label="$field->label" />
                                    @break
                                @case(CustomFieldType::Date)
                                    <flux:input wire:model="customFields.{{ $field->id }}" type="date" :label="$field->label" />
                                    @break
                                @case(CustomFieldType::Boolean)
                                    <flux:switch wire:model="customFields.{{ $field->id }}" :label="$field->label" />
                                    @break
                                @case(CustomFieldType::Select)
                                @case(CustomFieldType::MultiSelect)
                                    <flux:select
                                        wire:model="customFields.{{ $field->id }}"
                                        :label="$field->label"
                                        :multiple="$field->type === CustomFieldType::MultiSelect"
                                        placeholder="اختر"
                                    >
                                        @foreach ($field->options ?? [] as $option)
                                            <flux:select.option value="{{ $option }}">{{ $option }}</flux:select.option>
                                        @endforeach
                                    </flux:select>
                                    @break
                                @default
                                    <flux:input wire:model="customFields.{{ $field->id }}" :label="$field->label" />
                            @endswitch
                        </div>
                    @endforeach
                </div>
            </flux:fieldset>
        @endif

        <flux:fieldset class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:legend>الحلقة والملاحظات</flux:legend>

            <flux:select wire:model="courseCircleId" label="الحلقة في الدورة الجارية" placeholder="بلا تسجيل الآن" class="sm:max-w-md">
                @foreach ($this->courseCircles as $courseCircle)
                    <flux:select.option value="{{ $courseCircle->id }}">
                        {{ $courseCircle->circle->name }} · {{ $courseCircle->shift->name }}
                    </flux:select.option>
                @endforeach
            </flux:select>

            <flux:textarea wire:model="notes" label="ملاحظات عامة" rows="3" class="mt-6" />
        </flux:fieldset>

        <div class="flex gap-2">
            <flux:button type="submit" variant="primary" data-test="save-student">حفظ الاستمارة</flux:button>
            <flux:button :href="route('students.index')" wire:navigate variant="ghost">إلغاء</flux:button>
        </div>
    </form>
</div>
