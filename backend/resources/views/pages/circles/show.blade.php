<?php

use App\Actions\EnrollStudent;
use App\Actions\TransferStudent;
use App\Concerns\InteractsWithInstitute;
use App\Enums\EnrollmentStatus;
use App\Enums\TeacherRole;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Enrollment;
use App\Models\Student;
use App\Queries\CircleQuery;
use Flux\Flux;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('الحلقة')] class extends Component {
    use InteractsWithInstitute;

    public CourseCircle $courseCircle;

    public ?int $enrollStudentId = null;

    public ?int $transferringStudentId = null;

    public ?int $transferTargetId = null;

    public string $transferReason = '';

    public ?int $teacherId = null;

    public string $teacherRole = 'main';

    public function mount(CourseCircle $courseCircle): void
    {
        $this->courseCircle = $courseCircle->load('circle', 'shift.days', 'course');
    }

    private function query(): CircleQuery
    {
        return app(CircleQuery::class);
    }

    /**
     * @return Collection<int, Enrollment>
     */
    #[Computed]
    public function enrollments(): Collection
    {
        return $this->query()->activeEnrollments($this->courseCircle);
    }

    /**
     * طلاب المعهد غير المسجَّلين في أي حلقة ضمن هذه الدورة.
     *
     * @return Collection<int, Student>
     */
    #[Computed]
    public function enrollableStudents(): Collection
    {
        return $this->query()->enrollableStudents($this->courseCircle);
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function siblingCircles(): Collection
    {
        return $this->query()->transferTargets($this->courseCircle);
    }

    /**
     * @return Collection<int, \App\Models\Teacher>
     */
    #[Computed]
    public function assignableTeachers(): Collection
    {
        return $this->query()->assignableTeachers($this->courseCircle->course->institute);
    }

    /**
     * @return Collection<int, CourseCircleTeacher>
     */
    #[Computed]
    public function assignments(): Collection
    {
        return $this->query()->assignments($this->courseCircle);
    }

    public function enroll(EnrollStudent $enrollStudent): void
    {
        $this->validate(
            ['enrollStudentId' => ['required', 'integer']],
            attributes: ['enrollStudentId' => 'الطالب'],
        );

        $student = Student::findOrFail($this->enrollStudentId);

        try {
            $enrollStudent->handle($student, $this->courseCircle);
        } catch (\RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        $this->reset('enrollStudentId');
        unset($this->enrollments, $this->enrollableStudents);
        Flux::modal('enroll-student')->close();
        Flux::toast(variant: 'success', text: 'سُجِّل الطالب في الحلقة.');
    }

    public function startTransfer(Student $student): void
    {
        $this->transferringStudentId = $student->id;
        $this->transferTargetId = null;
        $this->transferReason = '';
        $this->resetValidation();

        Flux::modal('transfer-student')->show();
    }

    public function transfer(TransferStudent $transferStudent): void
    {
        $this->validate(
            ['transferTargetId' => ['required', 'integer']],
            attributes: ['transferTargetId' => 'الحلقة الجديدة'],
        );

        $student = Student::findOrFail($this->transferringStudentId);
        $target = CourseCircle::findOrFail($this->transferTargetId);

        try {
            $transferStudent->handle($student, $target, $this->transferReason ?: null, auth()->user());
        } catch (\RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->enrollments);
        Flux::modal('transfer-student')->close();
        Flux::toast(variant: 'success', text: 'نُقل الطالب — وسجل حضوره السابق محفوظ في الحلقة القديمة.');
    }

    public function withdraw(Enrollment $enrollment): void
    {
        $enrollment->update([
            'status' => EnrollmentStatus::Left,
            'left_on' => Carbon::today()->toDateString(),
        ]);

        unset($this->enrollments, $this->enrollableStudents);
        Flux::toast(variant: 'success', text: 'سُجِّل انسحاب الطالب.');
    }

    public function assignTeacher(): void
    {
        $validated = $this->validate([
            'teacherId' => ['required', 'integer'],
            'teacherRole' => ['required', Rule::enum(TeacherRole::class)],
        ], attributes: ['teacherId' => 'الأستاذ']);

        CourseCircleTeacher::updateOrCreate(
            ['course_circle_id' => $this->courseCircle->id, 'teacher_id' => $validated['teacherId']],
            ['role' => $validated['teacherRole'], 'joined_on' => Carbon::today()->toDateString(), 'left_on' => null],
        );

        $this->reset('teacherId');
        unset($this->assignments);
        Flux::modal('assign-teacher')->close();
        Flux::toast(variant: 'success', text: 'أُسند الأستاذ إلى الحلقة.');
    }

    public function unassignTeacher(CourseCircleTeacher $assignment): void
    {
        $assignment->update(['left_on' => Carbon::today()->toDateString()]);

        unset($this->assignments);
        Flux::toast(variant: 'success', text: 'أُنهي إسناد الأستاذ.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header
        :heading="$courseCircle->circle->name"
        :subheading="$courseCircle->course->name.' · '.$courseCircle->shift->name.' · '.implode(' · ', $courseCircle->shift->weekdayLabels())"
    >
        <x-slot name="actions">
            <flux:button :href="route('circles.index')" wire:navigate variant="ghost" icon="arrow-right">الحلقات</flux:button>
            <flux:modal.trigger name="enroll-student">
                <flux:button variant="primary" icon="user-plus" data-test="open-enroll">تسجيل طالب</flux:button>
            </flux:modal.trigger>
        </x-slot>
    </x-page-header>

    <div class="grid gap-4 sm:grid-cols-3">
        <x-stat-card label="المسجَّلون" :value="$this->enrollments->count()" />
        <x-stat-card label="الطاقة الاستيعابية" :value="$courseCircle->capacity ?? '—'" tone="ink" />
        <x-stat-card label="القاعة" :value="$courseCircle->room ?: '—'" tone="gold" />
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        <div class="flex items-center justify-between border-b border-sand-200 p-4 dark:border-zinc-700">
            <flux:heading size="lg">الأساتذة</flux:heading>
            <flux:modal.trigger name="assign-teacher">
                <flux:button size="sm" icon="plus" data-test="open-assign-teacher">إسناد أستاذ</flux:button>
            </flux:modal.trigger>
        </div>

        <div class="flex flex-wrap gap-2 p-4">
            @forelse ($this->assignments as $assignment)
                <flux:badge wire:key="assignment-{{ $assignment->id }}" color="zinc">
                    {{ $assignment->teacher->display_name }} · {{ $assignment->role->label() }}
                    <flux:badge.close wire:click="unassignTeacher('{{ $assignment->uuid }}')" />
                </flux:badge>
            @empty
                <flux:text>لا يوجد أستاذ مسنَد بعد.</flux:text>
            @endforelse
        </div>
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
            <flux:heading size="lg">الطلاب المسجَّلون</flux:heading>
        </div>

        @if ($this->enrollments->isEmpty())
            <flux:text class="p-6 text-center">لا يوجد طلاب مسجَّلون في هذه الحلقة.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الطالب</flux:table.column>
                    <flux:table.column>رقم المعرف</flux:table.column>
                    <flux:table.column>الهاتف</flux:table.column>
                    <flux:table.column>تاريخ التسجيل</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->enrollments as $enrollment)
                        <flux:table.row :key="$enrollment->id">
                            <flux:table.cell>
                                <flux:link :href="route('students.show', $enrollment->student)" wire:navigate>
                                    {{ $enrollment->student->full_name }}
                                </flux:link>
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $enrollment->student->registration_no ?: '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $enrollment->student->phone ?: '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $enrollment->enrolled_on?->toDateString() ?? '—' }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="startTransfer('{{ $enrollment->student->uuid }}')" icon="arrows-right-left">نقل إلى حلقة أخرى</flux:menu.item>
                                        <flux:menu.item wire:click="withdraw('{{ $enrollment->uuid }}')" icon="user-minus" variant="danger">تسجيل انسحاب</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="enroll-student" class="w-full max-w-lg">
        <form wire:submit="enroll" class="space-y-6">
            <flux:heading size="lg">تسجيل طالب في الحلقة</flux:heading>

            <flux:select wire:model="enrollStudentId" label="الطالب" placeholder="اختر طالباً غير مسجَّل في هذه الدورة">
                @foreach ($this->enrollableStudents as $student)
                    <flux:select.option value="{{ $student->id }}">{{ $student->full_name }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-enrollment">تسجيل</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="transfer-student" class="w-full max-w-lg">
        <form wire:submit="transfer" class="space-y-6">
            <flux:heading size="lg">نقل الطالب</flux:heading>
            <flux:text>التسجيل الحالي يُغلق بحالة «منقول»، وسجل الحضور القديم يبقى مربوطاً به.</flux:text>

            <flux:select wire:model="transferTargetId" label="الحلقة الجديدة" placeholder="اختر الحلقة">
                @foreach ($this->siblingCircles as $sibling)
                    <flux:select.option value="{{ $sibling->id }}">{{ $sibling->circle->name }} · {{ $sibling->shift->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:textarea wire:model="transferReason" label="سبب النقل" rows="2" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-transfer">نقل</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="assign-teacher" class="w-full max-w-lg">
        <form wire:submit="assignTeacher" class="space-y-6">
            <flux:heading size="lg">إسناد أستاذ</flux:heading>

            <flux:select wire:model="teacherId" label="الأستاذ" placeholder="اختر الأستاذ">
                @foreach ($this->assignableTeachers as $teacher)
                    <flux:select.option value="{{ $teacher->id }}">{{ $teacher->display_name }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:select wire:model="teacherRole" label="الدور">
                @foreach (App\Enums\TeacherRole::options() as $value => $label)
                    <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-assignment">إسناد</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
