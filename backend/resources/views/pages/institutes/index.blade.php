<?php

use App\Models\Institute;
use App\Queries\InstituteAdminQuery;
use App\Support\PanelScope;
use Flux\Flux;
use Illuminate\Pagination\LengthAwarePaginator;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

new #[Title('المعاهد')] class extends Component {
    use WithPagination;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    /**
     * @return LengthAwarePaginator<int, Institute>
     */
    #[Computed]
    public function institutes(): LengthAwarePaginator
    {
        return app(InstituteAdminQuery::class)->list($this->search);
    }

    public function currentInstituteId(): ?int
    {
        return PanelScope::resolve()?->id;
    }

    /**
     * الدخول إلى معهد: تبديل السياق ثم إعادة تحميل كاملة — كل ما في اللوحة مشتقّ
     * من المعهد، فإعادة بناء الخصائص المحسوبة واحدةً واحدة أطول وأخطأ.
     */
    public function enter(Institute $institute): void
    {
        if (! PanelScope::switchTo($institute)) {
            abort(403);
        }

        Flux::toast(variant: 'success', text: "أنت الآن داخل «{$institute->name}».");

        $this->redirect(route('dashboard'), navigate: false);
    }

    public function toggleActive(Institute $institute): void
    {
        $institute->update(['is_active' => ! $institute->is_active]);

        unset($this->institutes);
        Flux::toast(variant: 'success', text: $institute->is_active ? 'فُعّل المعهد.' : 'عُطّل المعهد.');
    }

    /**
     * حذف ناعم: SoftDeletes مفعّلة على النموذج، فالبيانات تبقى ويمكن التراجع من
     * قاعدة البيانات — والمعهد العامل لا يُحذف من تحت قدمَي صاحبه.
     */
    public function delete(Institute $institute): void
    {
        if ($institute->id === $this->currentInstituteId()) {
            Flux::toast(variant: 'danger', text: 'لا يمكن حذف المعهد الذي تعمل فيه الآن — بدّل إلى غيره أولاً.');

            return;
        }

        $institute->delete();

        unset($this->institutes);
        Flux::toast(variant: 'success', text: 'حُذف المعهد.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="المعاهد" subheading="إنشاء المعاهد وتحريرها والتنقّل بينها">
        <x-slot name="actions">
            <flux:button :href="route('institutes.overview')" wire:navigate variant="ghost" icon="chart-bar">لوحة المقارنة</flux:button>
            <flux:button :href="route('institutes.create')" wire:navigate variant="primary" icon="plus" data-test="new-institute">معهد جديد</flux:button>
        </x-slot>
    </x-page-header>

    <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث باسم المعهد" class="sm:max-w-md" />

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->institutes->isEmpty())
            <flux:text class="p-6 text-center">لا توجد معاهد مطابقة.</flux:text>
        @else
            <flux:table :paginate="$this->institutes">
                <flux:table.columns>
                    <flux:table.column>المعهد</flux:table.column>
                    <flux:table.column>الاسم المختصر</flux:table.column>
                    <flux:table.column>الحلقات</flux:table.column>
                    <flux:table.column>الطلاب</flux:table.column>
                    <flux:table.column>الأساتذة</flux:table.column>
                    <flux:table.column>الدورة الجارية</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->institutes as $institute)
                        <flux:table.row :key="$institute->id">
                            <flux:table.cell>
                                <div class="flex items-center gap-3">
                                    @if ($institute->logo_path)
                                        <img src="{{ Storage::url($institute->logo_path) }}" alt="" class="size-8 rounded-lg object-cover" />
                                    @else
                                        <flux:icon icon="building-library" class="size-8 text-ink-400 dark:text-zinc-500" />
                                    @endif

                                    <span>{{ $institute->name }}</span>

                                    @if ($institute->id === $this->currentInstituteId())
                                        <flux:badge size="sm" color="lime">الحالي</flux:badge>
                                    @endif
                                </div>
                            </flux:table.cell>
                            <flux:table.cell>{{ $institute->short_name ?: '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $institute->circles_count }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $institute->students_count }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $institute->teachers_count }}</flux:table.cell>
                            <flux:table.cell>{{ $institute->courses->first()?->name ?: '—' }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:badge size="sm" :color="$institute->is_active ? 'lime' : 'zinc'">
                                    {{ $institute->is_active ? 'فعّال' : 'معطّل' }}
                                </flux:badge>
                            </flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="enter('{{ $institute->uuid }}')" icon="arrow-left-end-on-rectangle">دخول كـ</flux:menu.item>
                                        <flux:menu.item :href="route('institutes.edit', $institute)" wire:navigate icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.item wire:click="toggleActive('{{ $institute->uuid }}')" :icon="$institute->is_active ? 'pause' : 'play'">
                                            {{ $institute->is_active ? 'تعطيل' : 'تفعيل' }}
                                        </flux:menu.item>
                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete('{{ $institute->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
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
