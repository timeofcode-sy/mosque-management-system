<?php

use App\Concerns\InteractsWithInstitute;
use App\Queries\DashboardOverviewQuery;
use App\Queries\StatsQuery;
use App\Support\DateRange;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

/**
 * شاشة الإحصائيات: كيان × مقياس × مدى، وكل مقياس بترتيبين — الأكثر والأقل.
 *
 * الجدولان متجاوران عمداً بدل مبدّل يخفي نصف المعلومة: «من تأخّر» سؤالٌ لا يقلّ
 * أهميةً عن «من تصدّر»، ورؤيتهما معاً هي فائدة الشاشة.
 */
new #[Title('الإحصائيات')] class extends Component {
    use InteractsWithInstitute;

    #[Url]
    public string $entity = StatsQuery::ENTITY_CIRCLES;

    #[Url]
    public string $metric = StatsQuery::METRIC_ATTENDANCE;

    #[Url]
    public string $range = DateRange::WEEK;

    /** عدد الصفوف في كل جدول من جدولَي الأكثر والأقل. */
    public int $limit = 8;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    #[Computed]
    public function dateRange(): DateRange
    {
        return DateRange::make($this->range, $this->currentCourse);
    }

    /**
     * @return Collection<int, array{id: int, name: string, value: float}>
     */
    #[Computed]
    public function leaderboard(): Collection
    {
        return app(StatsQuery::class)->leaderboard($this->entity, $this->metric, $this->dateRange, $this->currentCourse);
    }

    /**
     * @return Collection<int, array{id: int, name: string, value: float}>
     */
    #[Computed]
    public function top(): Collection
    {
        return $this->leaderboard->take($this->limit);
    }

    /**
     * الأقل: ذيل القائمة مقلوباً صعوداً. حين تقلّ الصفوف عن ضعف الحدّ يتقاطع الجدولان
     * — وهذا مقصود: القائمة القصيرة تُقرأ كاملةً من الطرفين.
     *
     * @return Collection<int, array{id: int, name: string, value: float}>
     */
    #[Computed]
    public function bottom(): Collection
    {
        return $this->leaderboard->reverse()->values()->take($this->limit);
    }

    /**
     * توزيع حالات الحضور في المدى — يكمّل الترتيبَ بصورة الحلقة كلها.
     *
     * @return array{present: int, absent: int, late: int, excused: int}
     */
    #[Computed]
    public function breakdown(): array
    {
        $days = max(1, Illuminate\Support\Carbon::parse($this->dateRange->from)->diffInDays($this->dateRange->to) + 1);

        return app(DashboardOverviewQuery::class)->statusBreakdown($this->currentCourse, (int) $days);
    }

    /**
     * @return Collection<int, array{date: string, rate: float, sessions: int}>
     */
    #[Computed]
    public function trend(): Collection
    {
        $days = max(1, Illuminate\Support\Carbon::parse($this->dateRange->from)->diffInDays($this->dateRange->to) + 1);

        return app(DashboardOverviewQuery::class)->trend($this->currentCourse, min(60, (int) $days));
    }

    public function unit(): string
    {
        return StatsQuery::unit($this->metric);
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الإحصائيات" :subheading="$this->currentCourse?->name" />

    @if ($this->currentCourse === null)
        <flux:callout icon="calendar-days" variant="warning">
            <flux:callout.heading>لا توجد دورة جارية</flux:callout.heading>
            <flux:callout.text>فعّل دورة لتظهر الإحصائيات.</flux:callout.text>
            <x-slot name="actions">
                <flux:button :href="route('courses.index')" wire:navigate variant="primary" size="sm">إدارة الدورات</flux:button>
            </x-slot>
        </flux:callout>
    @else
        <div class="flex flex-wrap items-end gap-3 rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:select wire:model.live="entity" label="الكيان" class="max-w-40" data-test="stats-entity">
                @foreach (StatsQuery::entities() as $value => $label)
                    <flux:select.option :value="$value">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:select wire:model.live="metric" label="المقياس" class="max-w-40" data-test="stats-metric">
                @foreach (StatsQuery::metrics() as $value => $label)
                    <flux:select.option :value="$value">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:select wire:model.live="range" label="المدى" class="max-w-40" data-test="stats-range">
                @foreach (['week', 'month', 'course'] as $value)
                    <flux:select.option :value="$value">{{ DateRange::options()[$value] }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="flex flex-1 items-center justify-end gap-2">
                <flux:badge color="zinc" class="latin-numerals">
                    {{ $this->dateRange->from }} → {{ $this->dateRange->to }}
                </flux:badge>
            </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-2">
            @foreach ([
                ['heading' => 'الأكثر '.StatsQuery::metrics()[$this->metric], 'rows' => $this->top, 'tone' => 'brand', 'test' => 'stats-top'],
                ['heading' => 'الأقل '.StatsQuery::metrics()[$this->metric], 'rows' => $this->bottom, 'tone' => 'gold', 'test' => 'stats-bottom'],
            ] as $panel)
                <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900" data-test="{{ $panel['test'] }}">
                    <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                        <flux:heading size="lg">{{ $panel['heading'] }}</flux:heading>
                    </div>

                    <div class="p-4">
                        <x-charts.bar :rows="$panel['rows']" :unit="$this->unit()" :tone="$panel['tone']" />
                    </div>
                </div>
            @endforeach
        </div>

        <div class="grid gap-6 lg:grid-cols-2">
            <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
                <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                    <flux:heading size="lg">منحنى الحضور في المدى</flux:heading>
                </div>
                <div class="p-4">
                    <x-charts.line :points="$this->trend" />
                </div>
            </div>

            <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
                <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                    <flux:heading size="lg">توزيع حالات التفقّد</flux:heading>
                </div>
                <div class="p-4">
                    <x-charts.donut
                        label="سجل"
                        :value="array_sum($this->breakdown)"
                        :segments="[
                            ['label' => 'حاضر', 'value' => $this->breakdown['present'], 'class' => 'stroke-present'],
                            ['label' => 'غائب', 'value' => $this->breakdown['absent'], 'class' => 'stroke-absent'],
                            ['label' => 'متأخّر', 'value' => $this->breakdown['late'], 'class' => 'stroke-late'],
                            ['label' => 'مأذون', 'value' => $this->breakdown['excused'], 'class' => 'stroke-excused'],
                        ]"
                    />
                </div>
            </div>
        </div>
    @endif
</div>
