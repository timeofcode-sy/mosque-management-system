<?php

use App\Queries\InstituteAdminQuery;
use App\Support\DateRange;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

/**
 * لوحة الإحصاء العامة — المعاهد كلها في شاشة واحدة.
 *
 * الشاشة الوحيدة في اللوحة التي لا نطاق معهد لها عمداً، ولذلك لا تستعمل
 * InteractsWithInstitute: قراءتها كلها تعبر المعاهد (انظر تحذير InstituteAdminQuery).
 */
new #[Title('لوحة المعاهد')] class extends Component {
    #[Url]
    public string $range = DateRange::MONTH;

    #[Computed]
    public function dateRange(): DateRange
    {
        return DateRange::make($this->range);
    }

    /**
     * @return array{rows: Collection<int, array<string, mixed>>, totals: array<string, mixed>}
     */
    #[Computed]
    public function overview(): array
    {
        return app(InstituteAdminQuery::class)->overview($this->dateRange);
    }

    /**
     * صفوف مخطّط الأعمدة: نسبة الحضور لكل معهد، تنازلياً.
     *
     * @return array<int, array{id: int, name: string, value: float}>
     */
    #[Computed]
    public function rateBars(): array
    {
        return collect($this->overview['rows'])
            ->map(fn (array $row): array => [
                'id' => $row['institute']->id,
                'name' => $row['institute']->short_name ?: $row['institute']->name,
                'value' => $row['rate'],
            ])
            ->sortByDesc('value')
            ->values()
            ->all();
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="لوحة المعاهد" :subheading="'من '.$this->dateRange->from.' إلى '.$this->dateRange->to">
        <x-slot name="actions">
            <flux:button :href="route('institutes.index')" wire:navigate variant="ghost" icon="building-library">إدارة المعاهد</flux:button>
        </x-slot>
    </x-page-header>

    <flux:radio.group wire:model.live="range" variant="segmented" size="sm">
        @foreach (\App\Support\DateRange::options() as $value => $label)
            @continue($value === \App\Support\DateRange::CUSTOM)
            <flux:radio value="{{ $value }}" :label="$label" />
        @endforeach
    </flux:radio.group>

    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <x-stat-card label="المعاهد الفعّالة" :value="$this->overview['totals']['institutes']" />
        <x-stat-card label="مجموع الطلاب" :value="$this->overview['totals']['students']" tone="gold" />
        <x-stat-card label="مجموع الحلقات" :value="$this->overview['totals']['circles']" tone="ink" />
        <x-stat-card
            label="متوسّط الحضور"
            :value="rtrim(rtrim(number_format($this->overview['totals']['rate'], 1, '.', ''), '0'), '.').'%'"
            hint="عبر كل المعاهد في المدى"
        />
    </div>

    <div class="grid gap-6 lg:grid-cols-3">
        <div class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900 lg:col-span-1">
            <flux:heading size="sm">نسب الحضور</flux:heading>
            <div class="mt-4">
                <x-charts.bar :rows="$this->rateBars" unit="%" />
            </div>
        </div>

        <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900 lg:col-span-2">
            @if (collect($this->overview['rows'])->isEmpty())
                <flux:text class="p-6 text-center">لا توجد معاهد بعد.</flux:text>
            @else
                <flux:table>
                    <flux:table.columns>
                        <flux:table.column>المعهد</flux:table.column>
                        <flux:table.column>الطلاب</flux:table.column>
                        <flux:table.column>الحلقات</flux:table.column>
                        <flux:table.column>الأساتذة</flux:table.column>
                        <flux:table.column>الجلسات</flux:table.column>
                        <flux:table.column>الحضور</flux:table.column>
                        <flux:table.column>النقاط</flux:table.column>
                    </flux:table.columns>

                    <flux:table.rows>
                        @foreach ($this->overview['rows'] as $row)
                            <flux:table.row :key="$row['institute']->id">
                                <flux:table.cell>
                                    <div class="flex items-center gap-2">
                                        <span>{{ $row['institute']->name }}</span>
                                        @unless ($row['institute']->is_active)
                                            <flux:badge size="sm" color="zinc">معطّل</flux:badge>
                                        @endunless
                                    </div>
                                </flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ $row['students'] }}</flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ $row['circles'] }}</flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ $row['teachers'] }}</flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ $row['sessions'] }}</flux:table.cell>
                                <flux:table.cell><x-attendance-rate :rate="$row['rate']" show-bar /></flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ rtrim(rtrim(number_format($row['points'], 2, '.', ''), '0'), '.') ?: '0' }}</flux:table.cell>
                            </flux:table.row>
                        @endforeach
                    </flux:table.rows>
                </flux:table>
            @endif
        </div>
    </div>
</div>
