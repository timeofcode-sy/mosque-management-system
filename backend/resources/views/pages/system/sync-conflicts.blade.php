<?php

use App\Models\SyncConflict;
use Flux\Flux;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Carbon;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * تعارضات المزامنة — أداة مبرمج (system.debug).
 *
 * الجدول sync_conflicts مبنيّ منذ المرحلة الرابعة ويكتب فيه ResolveAttendanceConflicts
 * ولا واجهة له. الحلّ الآلي «الخادم يفوز» يُطبَّق وقت الدفع؛ ما يبقى هنا هو المراجعة
 * البشرية: أن يرى المشرف القيمة المرفوضة ويقرّر — ولذلك العرض للقراءة، والفعل الوحيد
 * تعليمُ التعارض مراجَعاً.
 *
 * لا نطاق معهد لهذه الشاشة: التعارض يقع على مستوى الأجهزة لا المعاهد.
 */
new #[Title('تعارضات المزامنة')] class extends Component {
    use WithPagination;

    #[Url(except: 'pending')]
    public string $status = 'pending';

    public ?int $inspecting = null;

    public function updatedStatus(): void
    {
        $this->resetPage();
    }

    /**
     * @return LengthAwarePaginator<int, SyncConflict>
     */
    #[Computed]
    public function conflicts(): LengthAwarePaginator
    {
        return SyncConflict::query()
            ->with('reviewedBy:id,first_name,last_name')
            ->when($this->status === 'pending', fn ($query) => $query->whereNull('resolved_at'))
            ->when($this->status === 'reviewed', fn ($query) => $query->whereNotNull('resolved_at'))
            ->latest('id')
            ->paginate(20);
    }

    #[Computed]
    public function inspected(): ?SyncConflict
    {
        return $this->inspecting === null ? null : SyncConflict::find($this->inspecting);
    }

    public function inspect(SyncConflict $conflict): void
    {
        $this->inspecting = $conflict->id;

        Flux::modal('conflict-payload')->show();
    }

    public function markReviewed(SyncConflict $conflict): void
    {
        $conflict->update([
            'reviewed_by' => auth()->id(),
            'resolved_at' => Carbon::now(),
        ]);

        unset($this->conflicts);
        Flux::toast(variant: 'success', text: 'عُلّم التعارض مراجَعاً.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="تعارضات المزامنة" subheading="ما رفضه الخادم من دفعات الأجهزة — للمراجعة البشرية" />

    <flux:radio.group wire:model.live="status" variant="segmented" size="sm">
        <flux:radio value="pending" label="بانتظار المراجعة" />
        <flux:radio value="reviewed" label="مراجَعة" />
        <flux:radio value="all" label="الكل" />
    </flux:radio.group>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->conflicts->isEmpty())
            <flux:text class="p-6 text-center">لا توجد تعارضات — وهذا هو المتوقّع.</flux:text>
        @else
            <flux:table :paginate="$this->conflicts">
                <flux:table.columns>
                    <flux:table.column>الجدول</flux:table.column>
                    <flux:table.column>الصفّ</flux:table.column>
                    <flux:table.column>القرار</flux:table.column>
                    <flux:table.column>الجهاز</flux:table.column>
                    <flux:table.column>وقع في</flux:table.column>
                    <flux:table.column>المراجعة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->conflicts as $conflict)
                        <flux:table.row :key="$conflict->id">
                            <flux:table.cell class="latin-numerals">{{ $conflict->table_name }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals text-xs">{{ Str::limit($conflict->row_uuid, 13) }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $conflict->resolution }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals text-xs">{{ Str::limit((string) $conflict->device_uuid, 13) ?: '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $conflict->created_at?->format('Y-m-d H:i') }}</flux:table.cell>
                            <flux:table.cell>
                                @if ($conflict->resolved_at)
                                    <flux:badge size="sm" color="lime">{{ $conflict->reviewedBy?->name ?? 'مراجَع' }}</flux:badge>
                                @else
                                    <flux:badge size="sm" color="amber">بانتظار المراجعة</flux:badge>
                                @endif
                            </flux:table.cell>
                            <flux:table.cell>
                                <div class="flex gap-1">
                                    <flux:button wire:click="inspect('{{ $conflict->uuid }}')" size="sm" variant="subtle" icon="eye" />

                                    @unless ($conflict->resolved_at)
                                        <flux:button wire:click="markReviewed('{{ $conflict->uuid }}')" size="sm" variant="subtle" icon="check" />
                                    @endunless
                                </div>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="conflict-payload" class="w-full max-w-3xl">
        <div class="space-y-4">
            <flux:heading size="lg">حمولتا التعارض</flux:heading>

            @if ($this->inspected)
                <div class="grid gap-4 lg:grid-cols-2">
                    <div>
                        <flux:heading size="sm">قيمة الخادم (الفائزة)</flux:heading>
                        <pre dir="ltr" class="latin-numerals mt-2 max-h-80 overflow-auto rounded-lg bg-sand-100 p-3 text-xs dark:bg-zinc-800">{{ json_encode($this->inspected->server_payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                    </div>
                    <div>
                        <flux:heading size="sm">قيمة الجهاز (المرفوضة)</flux:heading>
                        <pre dir="ltr" class="latin-numerals mt-2 max-h-80 overflow-auto rounded-lg bg-sand-100 p-3 text-xs dark:bg-zinc-800">{{ json_encode($this->inspected->client_payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                    </div>
                </div>
            @endif

            <flux:modal.close><flux:button variant="ghost">إغلاق</flux:button></flux:modal.close>
        </div>
    </flux:modal>
</div>
