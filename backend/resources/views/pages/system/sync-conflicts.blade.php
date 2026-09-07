<?php

use App\Actions\OverturnSyncConflict;
use App\Concerns\InteractsWithInstitute;
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
 * تعارضات المزامنة — شاشة مدير المعهد والمشرف (conflicts.review).
 *
 * الجدول sync_conflicts مبنيّ منذ المرحلة الرابعة ويكتب فيه ResolveAttendanceConflicts.
 * الحلّ الآلي «الأحدث يفوز» يُطبَّق وقت الدفع لأنه يقع داخل دفعةٍ لا أمام بشر؛ وما هنا
 * **استئنافٌ بعديّ**: أن يرى صاحبُ القرار القيمتين فيُبقي حكم الخادم أو يقلبه.
 *
 * 🔄 2026-09-07: كانت خلف system.debug — أي المبرمج وحده — وبلا نطاق معهد، وفعلُها
 * الوحيد «عُلّم مراجَعاً». صارت خلف conflicts.review (يملكها المشرف ومدير المعهد منذ
 * المرحلة الأولى بلا مسار يحرسها)، **محصورةً بمعهد المستخدم**، وبفعلٍ يقلب الحكم.
 *
 * والمبرمج وحده يرى المعاهد كلَّها: لأنها تبقى أداةَ تشخيصٍ عنده، ولأن صفوف ما قبل
 * الهجرة بلا معهد فلا يراها غيره.
 */
new #[Title('تعارضات المزامنة')] class extends Component {
    use InteractsWithInstitute, WithPagination;

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
        return $this->scoped()
            ->with('reviewedBy:id,first_name,last_name')
            ->when($this->status === 'pending', fn ($query) => $query->whereNull('resolved_at'))
            ->when($this->status === 'reviewed', fn ($query) => $query->whereNotNull('resolved_at'))
            ->latest('id')
            ->paginate(20);
    }

    /**
     * الحصر بالمعهد العامل — والمبرمج يعبره.
     *
     * الحصرُ هنا لا في العرض: بدونه يفتح مديرُ معهدٍ تعارضاتِ معهدٍ آخر بتغيير رقم
     * الصفحة، وهو نفسُ التسريب الذي سُدّ في اللوحة كلّها في المرحلة 4.6.
     *
     * @return \Illuminate\Database\Eloquent\Builder<SyncConflict>
     */
    private function scoped(): \Illuminate\Database\Eloquent\Builder
    {
        return SyncConflict::query()
            ->unless(auth()->user()?->can('system.debug'), fn ($query) => $query->where('institute_id', $this->institute?->id));
    }

    #[Computed]
    public function inspected(): ?SyncConflict
    {
        return $this->inspecting === null ? null : $this->scoped()->find($this->inspecting);
    }

    public function inspect(string $uuid): void
    {
        $this->inspecting = $this->find($uuid)->id;

        Flux::modal('conflict-payload')->show();
    }

    /**
     * إبقاء حكم الخادم: التعارض يُختم مراجَعاً ولا يُكتب شيء — الصفّ أصلاً يحمل قيمة
     * الخادم منذ لحظة الدفع.
     */
    public function markReviewed(string $uuid): void
    {
        $this->find($uuid)->update([
            'reviewed_by' => auth()->id(),
            'resolved_at' => Carbon::now(),
        ]);

        unset($this->conflicts);
        Flux::toast(variant: 'success', text: 'أُبقيت قيمة الخادم، وعُلّم التعارض مراجَعاً.');
    }

    /**
     * قلبُ الحكم: اعتماد قيمة الجهاز التي رفضها الخادم.
     *
     * الرفضُ الوحيد المتوقَّع هنا جلسةٌ مقفلة — TakeAttendance ترفضها ولو بـ amend،
     * فتُعرض رسالتُها كما هي بدل خطأ 500 صامت.
     */
    public function overturn(string $uuid, OverturnSyncConflict $overturn): void
    {
        /**
         * الحسم خارج try عمداً: ModelNotFoundException يرث RuntimeException، فلو دخل
         * الكتلةَ لَصار خرقُ النطاق «رسالةً لطيفة» بدل أن يكون 404 كما يجب.
         */
        $conflict = $this->find($uuid);

        try {
            $overturn->handle($conflict, auth()->user());
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->conflicts, $this->inspected);
        Flux::modal('conflict-payload')->close();
        Flux::toast(variant: 'success', text: 'اعتُمدت قيمة الجهاز، وسجِّل التغيير للأجهزة.');
    }

    /**
     * كل فعل يمرّ بالنطاق نفسه: المعرّف يصل من المتصفّح، فلولا ذلك لَعدّل مديرُ معهدٍ
     * تعارضَ معهدٍ آخر بمعرّفٍ منسوخ — وحارسُ المسار لا يمنع ذلك، فهو صلاحيةٌ لا نطاق.
     */
    private function find(string $uuid): SyncConflict
    {
        return $this->scoped()->where('uuid', $uuid)->firstOrFail();
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="تعارضات المزامنة" subheading="ما رفضه الخادم من دفعات الأجهزة — لك أن تُبقي حكمه أو تقلبه" />

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
                                    <flux:button wire:click="inspect('{{ $conflict->uuid }}')" size="sm" variant="subtle" icon="eye" title="عرض الحمولتين" />

                                    @unless ($conflict->resolved_at)
                                        <flux:button wire:click="markReviewed('{{ $conflict->uuid }}')" size="sm" variant="subtle" icon="check" title="أبقِ قيمة الخادم" />
                                        <flux:button wire:click="overturn('{{ $conflict->uuid }}')" wire:confirm="ستُعتمد قيمة الجهاز بدل قيمة الخادم، ويصل التغيير كلَّ الأجهزة. متابعة؟" size="sm" variant="subtle" icon="arrow-uturn-left" title="اعتمِد قيمة الجهاز" />
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

            <div class="flex items-center gap-2">
                @if ($this->inspected && ! $this->inspected->resolved_at)
                    <flux:button
                        wire:click="overturn('{{ $this->inspected->uuid }}')"
                        wire:confirm="ستُعتمد قيمة الجهاز بدل قيمة الخادم، ويصل التغيير كلَّ الأجهزة. متابعة؟"
                        variant="primary"
                        icon="arrow-uturn-left"
                    >اعتمِد قيمة الجهاز</flux:button>

                    <flux:button wire:click="markReviewed('{{ $this->inspected->uuid }}')" icon="check">أبقِ قيمة الخادم</flux:button>
                @endif

                <flux:spacer />

                <flux:modal.close><flux:button variant="ghost">إغلاق</flux:button></flux:modal.close>
            </div>
        </div>
    </flux:modal>
</div>
