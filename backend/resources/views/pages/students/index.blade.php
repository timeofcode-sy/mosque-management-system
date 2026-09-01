<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\StudentStatus;
use App\Models\CourseCircle;
use App\Models\Student;
use App\Queries\StudentListQuery;
use Flux\Flux;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

new #[Title('الطلاب')] class extends Component {
    use InteractsWithInstitute, WithPagination;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    #[Url(except: '')]
    public string $status = '';

    #[Url(except: '')]
    public string $courseCircleId = '';

    public function mount(): void
    {
        $this->requireInstitute();
    }

    public function updated(string $property): void
    {
        if (in_array($property, ['search', 'status', 'courseCircleId'], true)) {
            $this->resetPage();
        }
    }

    private function query(): StudentListQuery
    {
        return app(StudentListQuery::class);
    }

    /**
     * @return LengthAwarePaginator<int, Student>
     */
    #[Computed]
    public function students(): LengthAwarePaginator
    {
        return $this->query()->paginate(
            $this->institute,
            $this->search,
            $this->status,
            $this->courseCircleId,
        );
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function courseCircles(): Collection
    {
        return $this->query()->filterableCircles($this->currentCourse);
    }

    public function delete(Student $student): void
    {
        $student->delete();

        unset($this->students);
        Flux::toast(variant: 'success', text: 'حُذف الطالب — بياناته قابلة للاسترجاع.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الطلاب" :subheading="$this->institute?->name">
        <x-slot name="actions">
            <flux:button :href="route('students.create')" wire:navigate variant="primary" icon="plus" data-test="new-student">
                تسجيل طالب
            </flux:button>
        </x-slot>
    </x-page-header>

    <div class="grid gap-4 sm:grid-cols-3">
        <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بالاسم أو رقم المعرف أو الهاتف" />

        <flux:select wire:model.live="status" placeholder="كل الحالات">
            <flux:select.option value="">كل الحالات</flux:select.option>
            @foreach (StudentStatus::options() as $value => $label)
                <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
            @endforeach
        </flux:select>

        <flux:select wire:model.live="courseCircleId" placeholder="كل الحلقات">
            <flux:select.option value="">كل الحلقات</flux:select.option>
            @foreach ($this->courseCircles as $courseCircle)
                <flux:select.option value="{{ $courseCircle->id }}">{{ $courseCircle->circle->name }}</flux:select.option>
            @endforeach
        </flux:select>
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->students->isEmpty())
            <flux:text class="p-6 text-center">لا توجد نتائج مطابقة.</flux:text>
        @else
            <flux:table :paginate="$this->students">
                <flux:table.columns>
                    <flux:table.column>الطالب</flux:table.column>
                    <flux:table.column>رقم المعرف</flux:table.column>
                    <flux:table.column>الحلقة الحالية</flux:table.column>
                    <flux:table.column>الهاتف</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->students as $student)
                        @php $enrollment = $student->enrollments->first(); @endphp

                        <flux:table.row :key="$student->id">
                            <flux:table.cell>
                                <flux:link :href="route('students.show', $student)" wire:navigate>{{ $student->full_name }}</flux:link>
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $student->registration_no ?: '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $enrollment?->courseCircle->circle->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $student->phone ?: '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $student->status->label() }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item :href="route('students.show', $student)" wire:navigate icon="identification">الملف</flux:menu.item>
                                        <flux:menu.item :href="route('students.edit', $student)" wire:navigate icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete('{{ $student->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>
</div>
