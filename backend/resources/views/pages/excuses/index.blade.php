<?php

use App\Actions\ReviewAbsenceExcuse;
use App\Actions\SubmitAbsenceExcuse;
use App\Concerns\InteractsWithInstitute;
use App\Enums\ExcuseStatus;
use App\Models\AbsenceExcuse;
use App\Models\Student;
use App\Queries\AbsenceExcuseQuery;
use Flux\Flux;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

new #[Title('أذونات الغياب')] class extends Component {
    use InteractsWithInstitute, WithPagination;

    #[Url]
    public string $status = '';

    #[Url]
    public string $search = '';

    /** نموذج الإذن الجديد */
    public ?int $studentId = null;

    public string $from_date = '';

    public string $to_date = '';

    public string $reason = '';

    /** نموذج المراجعة */
    public ?int $reviewingId = null;

    public string $reviewNote = '';

    public function mount(): void
    {
        $this->requireInstitute();
    }

    private function query(): AbsenceExcuseQuery
    {
        return app(AbsenceExcuseQuery::class);
    }

    /**
     * @return LengthAwarePaginator<int, AbsenceExcuse>
     */
    #[Computed]
    public function excuses(): LengthAwarePaginator
    {
        return $this->query()->paginate($this->institute, $this->status, $this->search);
    }

    #[Computed]
    public function pendingCount(): int
    {
        return $this->query()->pendingCount($this->institute);
    }

    /**
     * @return Collection<int, Student>
     */
    #[Computed]
    public function students(): Collection
    {
        return $this->query()->selectableStudents($this->institute);
    }

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    public function updatedStatus(): void
    {
        $this->resetPage();
    }

    public function create(): void
    {
        $this->reset('studentId', 'from_date', 'to_date', 'reason');
        $this->resetValidation();

        Flux::modal('excuse-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'studentId' => ['required', Rule::exists('students', 'id')->where('institute_id', $this->institute?->id)],
            'from_date' => ['required', 'date'],
            'to_date' => ['required', 'date', 'after_or_equal:from_date'],
            'reason' => ['required', 'string', 'max:255'],
        ], attributes: [
            'studentId' => 'الطالب',
            'from_date' => 'من تاريخ',
            'to_date' => 'إلى تاريخ',
            'reason' => 'السبب',
        ]);

        app(SubmitAbsenceExcuse::class)->handle(
            Student::findOrFail($validated['studentId']),
            [
                'from_date' => $validated['from_date'],
                'to_date' => $validated['to_date'],
                'reason' => $validated['reason'],
            ],
            auth()->user(),
        );

        unset($this->excuses, $this->pendingCount);

        Flux::modal('excuse-form')->close();
        Flux::toast(variant: 'success', text: 'سُجّل الإذن وهو بانتظار المراجعة.');
    }

    public function startReview(AbsenceExcuse $excuse): void
    {
        $this->reviewingId = $excuse->id;
        $this->reviewNote = (string) $excuse->review_note;
        $this->resetValidation();

        Flux::modal('review-excuse')->show();
    }

    public function decide(string $decision): void
    {
        $status = ExcuseStatus::tryFrom($decision);

        if ($status === null || $this->reviewingId === null) {
            return;
        }

        app(ReviewAbsenceExcuse::class)->handle(
            AbsenceExcuse::findOrFail($this->reviewingId),
            $status,
            auth()->user(),
            $this->reviewNote ?: null,
        );

        unset($this->excuses, $this->pendingCount);

        Flux::modal('review-excuse')->close();

        Flux::toast(
            variant: $status === ExcuseStatus::Approved ? 'success' : 'warning',
            text: $status === ExcuseStatus::Approved
                ? 'قُبل الإذن، وحُوّل غياب الطالب في الجلسات غير المقفلة إلى "مأذون".'
                : 'رُفض الإذن.',
        );
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="أذونات الغياب المسبقة" :subheading="$this->institute?->name">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-excuse">إذن جديد</flux:button>
        </x-slot>
    </x-page-header>

    <div class="grid gap-4 sm:grid-cols-3">
        <x-stat-card label="بانتظار المراجعة" :value="$this->pendingCount" tone="gold" />
        <x-stat-card label="المعروضة" :value="$this->excuses->total()" />
        <x-stat-card label="الطلاب" :value="$this->students->count()" tone="ink" />
    </div>

    <div class="flex flex-wrap items-end gap-3 rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900">
        <flux:input wire:model.live.debounce.300ms="search" label="بحث" placeholder="اسم الطالب أو رقم المعرف" class="max-w-64" icon="magnifying-glass" />

        <flux:select wire:model.live="status" label="الحالة" class="max-w-48" data-test="excuse-status-filter">
            <flux:select.option value="">الكل</flux:select.option>
            @foreach (ExcuseStatus::options() as $value => $label)
                <flux:select.option :value="$value">{{ $label }}</flux:select.option>
            @endforeach
        </flux:select>
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->excuses->isEmpty())
            <flux:text class="p-6 text-center">لا توجد أذونات مطابقة.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الطالب</flux:table.column>
                    <flux:table.column>من</flux:table.column>
                    <flux:table.column>إلى</flux:table.column>
                    <flux:table.column>السبب</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column>راجعها</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->excuses as $excuse)
                        <flux:table.row :key="$excuse->id">
                            <flux:table.cell>
                                <flux:link :href="route('students.show', $excuse->student)" wire:navigate>
                                    {{ $excuse->student->full_name }}
                                </flux:link>
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $excuse->from_date->toDateString() }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $excuse->to_date->toDateString() }}</flux:table.cell>
                            <flux:table.cell>{{ $excuse->reason }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:badge size="sm" :color="match ($excuse->status) {
                                    ExcuseStatus::Approved => 'green',
                                    ExcuseStatus::Rejected => 'red',
                                    ExcuseStatus::Pending => 'amber',
                                }">
                                    {{ $excuse->status->label() }}
                                </flux:badge>
                            </flux:table.cell>
                            <flux:table.cell>{{ $excuse->reviewedBy?->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:button
                                    size="sm"
                                    variant="subtle"
                                    icon="check-circle"
                                    wire:click="startReview('{{ $excuse->uuid }}')"
                                    data-test="review-excuse-{{ $excuse->id }}"
                                >
                                    مراجعة
                                </flux:button>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>

            <div class="p-4">{{ $this->excuses->links() }}</div>
        @endif
    </div>

    <flux:modal name="excuse-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">إذن غياب جديد</flux:heading>

            <flux:select wire:model="studentId" label="الطالب" placeholder="اختر الطالب" data-test="excuse-student">
                @foreach ($this->students as $student)
                    <flux:select.option :value="$student->id">
                        {{ $student->full_name }}{{ $student->registration_no ? ' · '.$student->registration_no : '' }}
                    </flux:select.option>
                @endforeach
            </flux:select>

            <div class="grid gap-4 sm:grid-cols-2">
                <flux:input type="date" wire:model="from_date" label="من تاريخ" class="latin-numerals" />
                <flux:input type="date" wire:model="to_date" label="إلى تاريخ" class="latin-numerals" />
            </div>

            <flux:input wire:model="reason" label="السبب" placeholder="سفر، مرض، ظرف عائلي…" />

            <div class="flex justify-end gap-2">
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                <flux:button type="submit" variant="primary" data-test="save-excuse">حفظ</flux:button>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="review-excuse" class="w-full max-w-lg">
        <div class="space-y-6">
            <flux:heading size="lg">مراجعة الإذن</flux:heading>

            <flux:callout icon="information-circle" variant="secondary">
                <flux:callout.text>
                    قبول الإذن يحوّل غياب الطالب إلى «مأذون» في كل جلسة غير مقفلة يغطّيها الإذن،
                    ويعيد حساب نسبة الحلقة وترتيبها.
                </flux:callout.text>
            </flux:callout>

            <flux:textarea wire:model="reviewNote" label="ملاحظة المراجعة" rows="3" />

            <div class="flex justify-end gap-2">
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                <flux:button wire:click="decide('rejected')" variant="danger" data-test="reject-excuse">رفض</flux:button>
                <flux:button wire:click="decide('approved')" variant="primary" data-test="approve-excuse">قبول</flux:button>
            </div>
        </div>
    </flux:modal>
</div>
