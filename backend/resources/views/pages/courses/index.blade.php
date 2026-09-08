<?php

use App\Actions\ActivateCourse;
use App\Actions\CloneCourseCircles;
use App\Actions\SaveCourse;
use App\Concerns\InteractsWithInstitute;
use App\Enums\CourseStatus;
use App\Models\Course;
use App\Queries\InstituteCatalogQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('الدورات')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $name = '';

    public string $starts_on = '';

    public string $ends_on = '';

    public string $status = 'draft';

    public string $notes = '';

    public ?int $cloningId = null;

    public ?int $cloneSourceId = null;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, Course>
     */
    #[Computed]
    public function courses(): Collection
    {
        return app(InstituteCatalogQuery::class)->courses($this->institute);
    }

    public function create(): void
    {
        $this->reset('editingId', 'name', 'starts_on', 'ends_on', 'notes');
        $this->status = CourseStatus::Draft->value;
        $this->resetValidation();

        Flux::modal('course-form')->show();
    }

    public function edit(Course $course): void
    {
        $this->editingId = $course->id;
        $this->name = $course->name;
        $this->starts_on = $course->starts_on->toDateString();
        $this->ends_on = $course->ends_on?->toDateString() ?? '';
        $this->status = $course->status->value;
        $this->notes = (string) $course->notes;
        $this->resetValidation();

        Flux::modal('course-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'starts_on' => ['required', 'date'],
            'ends_on' => ['nullable', 'date', 'after_or_equal:starts_on'],
            'status' => ['required', Rule::enum(CourseStatus::class)],
            'notes' => ['nullable', 'string'],
        ]);

        $validated['ends_on'] = $validated['ends_on'] ?: null;

        app(SaveCourse::class)->handle(
            $this->institute,
            $validated,
            $this->editingId === null ? null : Course::find($this->editingId),
        );

        unset($this->courses);
        Flux::modal('course-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظت الدورة.');
    }

    public function activate(Course $course, ActivateCourse $activateCourse): void
    {
        $activateCourse->handle($course);

        unset($this->courses, $this->currentCourse);
        Flux::toast(variant: 'success', text: 'صارت هذه هي الدورة الجارية.');
    }

    public function archive(Course $course): void
    {
        $course->update(['status' => CourseStatus::Archived, 'is_current' => false]);

        unset($this->courses, $this->currentCourse);
        Flux::toast(variant: 'success', text: 'أُرشفت الدورة.');
    }

    public function startClone(Course $course): void
    {
        $this->cloningId = $course->id;
        $this->cloneSourceId = $this->courses
            ->where('id', '!=', $course->id)
            ->sortByDesc('starts_on')
            ->first()?->id;

        $this->resetValidation();

        Flux::modal('clone-circles')->show();
    }

    public function cloneStructure(CloneCourseCircles $cloneCourseCircles): void
    {
        $this->validate(
            ['cloneSourceId' => ['required', 'integer', 'different:cloningId']],
            attributes: ['cloneSourceId' => 'الدورة المصدر'],
        );

        $target = $this->institute->courses()->findOrFail($this->cloningId);
        $source = $this->institute->courses()->findOrFail($this->cloneSourceId);

        $result = $cloneCourseCircles->handle($source, $target);

        unset($this->courses);
        Flux::modal('clone-circles')->close();
        Flux::toast(
            variant: 'success',
            text: "نُسخ {$result['circles']} حلقة و{$result['shifts']} دوام — بلا تسجيلات ولا سجل تفقّد.",
        );
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الدورات" subheading="الدورة هي نطاق تصفير عدّادات الغياب — وسجل الدورة السابقة يبقى محفوظاً">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-course">دورة جديدة</flux:button>
        </x-slot>
    </x-page-header>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->courses->isEmpty())
            <flux:text class="p-6 text-center">لا توجد دورات بعد.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الدورة</flux:table.column>
                    <flux:table.column>من</flux:table.column>
                    <flux:table.column>إلى</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column>الحلقات</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->courses as $course)
                        <flux:table.row :key="$course->id">
                            <flux:table.cell>
                                <div class="flex items-center gap-2">
                                    {{ $course->name }}
                                    @if ($course->is_current)
                                        <flux:badge color="green" size="sm">جارية</flux:badge>
                                    @endif
                                </div>
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $course->starts_on->toDateString() }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $course->ends_on?->toDateString() ?? '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $course->status->label() }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $course->course_circles_count }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />

                                    <flux:menu>
                                        <flux:menu.item wire:click="edit('{{ $course->uuid }}')" icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.item wire:click="startClone('{{ $course->uuid }}')" icon="document-duplicate">استنساخ بنية دورة سابقة</flux:menu.item>

                                        @unless ($course->is_current)
                                            <flux:menu.item wire:click="activate('{{ $course->uuid }}')" icon="check-circle">اجعلها الدورة الجارية</flux:menu.item>
                                        @endunless

                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="archive('{{ $course->uuid }}')" icon="archive-box" variant="danger">أرشفة</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="course-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل الدورة' : 'دورة جديدة' }}</flux:heading>

            <flux:input wire:model="name" label="اسم الدورة" required />

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="starts_on" type="date" label="تبدأ في" required />
                <flux:input wire:model="ends_on" type="date" label="تنتهي في" />
            </div>

            <flux:select wire:model="status" label="الحالة">
                @foreach (App\Enums\CourseStatus::options() as $value => $label)
                    <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:textarea wire:model="notes" label="ملاحظات" rows="2" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-course">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="clone-circles" class="w-full max-w-lg">
        <form wire:submit="cloneStructure" class="space-y-6">
            <flux:heading size="lg">استنساخ بنية دورة سابقة</flux:heading>
            <flux:text>تُنسخ الدوامات والحلقات وأساتذتها فقط — بلا تسجيلات ولا سجل تفقّد.</flux:text>

            <flux:select wire:model="cloneSourceId" label="الدورة المصدر" placeholder="اختر الدورة">
                @foreach ($this->courses->where('id', '!=', $cloningId) as $course)
                    <flux:select.option value="{{ $course->id }}">{{ $course->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="run-clone">استنساخ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
