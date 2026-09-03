<?php

use App\Enums\SyncOperation;
use App\Models\ChangeLog;
use Illuminate\Pagination\LengthAwarePaginator;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * سجل التغييرات — أداة مبرمج (system.debug).
 *
 * change_log هو مصدر sync/pull نفسه: معرّفه التسلسلي هو server_seq الذي يتقدّم به
 * كل جهاز. قراءته من الواجهة تجيب سؤالين لا ثالث لهما وقت العطل: مَن غيّر ماذا،
 * وأين وقف تسلسل جهازٍ بعينه.
 */
new #[Title('سجل التغييرات')] class extends Component {
    use WithPagination;

    #[Url(except: '')]
    public string $table = '';

    #[Url(except: '')]
    public string $operation = '';

    #[Url(as: 'q', except: '')]
    public string $search = '';

    public ?int $inspecting = null;

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    /**
     * @return LengthAwarePaginator<int, ChangeLog>
     */
    #[Computed]
    public function entries(): LengthAwarePaginator
    {
        return ChangeLog::query()
            ->with('actor:id,first_name,last_name')
            ->when($this->table !== '', fn ($query) => $query->where('table_name', $this->table))
            ->when($this->operation !== '', fn ($query) => $query->where('operation', $this->operation))
            ->when($this->search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('row_uuid', 'like', "%{$this->search}%")
                ->orWhere('scope_key', 'like', "%{$this->search}%")))
            ->latest('id')
            ->paginate(30);
    }

    /**
     * @return array<int, string>
     */
    #[Computed]
    public function tables(): array
    {
        return ChangeLog::query()->distinct()->orderBy('table_name')->pluck('table_name')->all();
    }

    #[Computed]
    public function inspected(): ?ChangeLog
    {
        return $this->inspecting === null ? null : ChangeLog::find($this->inspecting);
    }

    public function inspect(int $id): void
    {
        $this->inspecting = $id;

        \Flux\Flux::modal('entry-payload')->show();
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="سجل التغييرات" subheading="مصدر sync/pull نفسه — من غيّر ماذا ومتى" />

    <div class="flex flex-wrap items-end gap-4">
        <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بمعرّف الصفّ أو مفتاح النطاق" class="sm:max-w-xs" />

        <flux:select wire:model.live="table" class="sm:max-w-56">
            <flux:select.option value="">كل الجداول</flux:select.option>
            @foreach ($this->tables as $name)
                <flux:select.option value="{{ $name }}">{{ $name }}</flux:select.option>
            @endforeach
        </flux:select>

        <flux:select wire:model.live="operation" class="sm:max-w-40">
            <flux:select.option value="">كل العمليات</flux:select.option>
            @foreach (SyncOperation::options() as $value => $label)
                <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
            @endforeach
        </flux:select>
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->entries->isEmpty())
            <flux:text class="p-6 text-center">لا توجد قيود مطابقة.</flux:text>
        @else
            <flux:table :paginate="$this->entries">
                <flux:table.columns>
                    <flux:table.column>التسلسل</flux:table.column>
                    <flux:table.column>الجدول</flux:table.column>
                    <flux:table.column>الصفّ</flux:table.column>
                    <flux:table.column>العملية</flux:table.column>
                    <flux:table.column>النطاق</flux:table.column>
                    <flux:table.column>الفاعل</flux:table.column>
                    <flux:table.column>الوقت</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->entries as $entry)
                        <flux:table.row :key="$entry->id">
                            <flux:table.cell class="latin-numerals">{{ $entry->id }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $entry->table_name }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals text-xs">{{ Str::limit($entry->row_uuid, 13) }}</flux:table.cell>
                            <flux:table.cell>{{ $entry->operation->label() }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals text-xs">{{ $entry->scope_key }}</flux:table.cell>
                            <flux:table.cell>{{ $entry->actor?->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $entry->created_at?->format('Y-m-d H:i:s') }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:button wire:click="inspect({{ $entry->id }})" size="sm" variant="subtle" icon="eye" />
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="entry-payload" class="w-full max-w-2xl">
        <div class="space-y-4">
            <flux:heading size="lg">حمولة القيد</flux:heading>

            @if ($this->inspected)
                <pre dir="ltr" class="latin-numerals max-h-96 overflow-auto rounded-lg bg-sand-100 p-3 text-xs dark:bg-zinc-800">{{ json_encode($this->inspected->payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
            @endif

            <flux:modal.close><flux:button variant="ghost">إغلاق</flux:button></flux:modal.close>
        </div>
    </flux:modal>
</div>
