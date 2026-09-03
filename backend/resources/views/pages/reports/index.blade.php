<?php

use App\Actions\BuildCircleDailyReport;
use App\Actions\BuildCirclePointsReport;
use App\Concerns\InteractsWithInstitute;
use App\Models\CourseCircle;
use App\Models\Shift;
use App\Queries\AttendanceBoardQuery;
use App\Queries\CircleRankingQuery;
use App\Support\DateRange;
use App\Support\HijriDate;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

new #[Title('التقارير')] class extends Component {
    use InteractsWithInstitute;

    #[Url]
    public string $date = '';

    #[Url]
    public string $shiftId = '';

    #[Url]
    public string $courseCircleId = '';

    #[Url]
    public string $mode = 'daily';

    /** مدى تقرير النقاط: أسبوع · شهر · الدورة كاملة · مخصّص. */
    #[Url]
    public string $range = DateRange::WEEK;

    #[Url]
    public string $rangeFrom = '';

    #[Url]
    public string $rangeTo = '';

    public function mount(): void
    {
        $this->requireInstitute();

        if ($this->date === '') {
            $this->date = Carbon::today()->toDateString();
        }
    }

    /**
     * @return Collection<int, Shift>
     */
    #[Computed]
    public function shifts(): Collection
    {
        return app(AttendanceBoardQuery::class)->shifts($this->currentCourse);
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function courseCircles(): Collection
    {
        if ($this->currentCourse === null) {
            return new Collection;
        }

        return $this->currentCourse->courseCircles()
            ->with('circle', 'shift')
            ->when($this->shiftId !== '', fn ($query) => $query->where('shift_id', (int) $this->shiftId))
            ->get()
            ->sortBy(fn (CourseCircle $courseCircle) => $courseCircle->circle->sort_order)
            ->values();
    }

    #[Computed]
    public function selectedCircle(): ?CourseCircle
    {
        if ($this->courseCircleId === '') {
            return $this->courseCircles->first();
        }

        return $this->courseCircles->firstWhere('id', (int) $this->courseCircleId);
    }

    #[Computed]
    public function selectedShift(): ?Shift
    {
        if ($this->shiftId !== '') {
            return $this->shifts->firstWhere('id', (int) $this->shiftId);
        }

        return $this->selectedCircle?->shift ?? $this->shifts->first();
    }

    /**
     * @return array<string, mixed>|null
     */
    #[Computed]
    public function circleReport(): ?array
    {
        $courseCircle = $this->selectedCircle;

        return $courseCircle === null
            ? null
            : app(BuildCircleDailyReport::class)->handle($courseCircle, $this->date);
    }

    #[Computed]
    public function dateRange(): DateRange
    {
        return DateRange::make($this->range, $this->currentCourse, $this->rangeFrom ?: null, $this->rangeTo ?: null, $this->date);
    }

    /**
     * @return array<string, mixed>|null
     */
    #[Computed]
    public function pointsReport(): ?array
    {
        $courseCircle = $this->selectedCircle;

        return $courseCircle === null
            ? null
            : app(BuildCirclePointsReport::class)->handle($courseCircle, $this->dateRange);
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function ranking(): Collection
    {
        $shift = $this->selectedShift;

        if ($shift === null) {
            return new Collection;
        }

        $ranking = app(CircleRankingQuery::class);

        return $this->mode === 'cumulative'
            ? $ranking->cumulative($shift, $this->date)
            : $ranking->daily($shift, $this->date);
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="التقارير" :subheading="$this->currentCourse?->name" />

    @if ($this->currentCourse === null)
        <flux:callout icon="calendar-days" variant="warning">
            <flux:callout.heading>لا توجد دورة جارية</flux:callout.heading>
            <flux:callout.text>فعّل دورة لتظهر التقارير.</flux:callout.text>
            <x-slot name="actions">
                <flux:button :href="route('courses.index')" wire:navigate variant="primary" size="sm">إدارة الدورات</flux:button>
            </x-slot>
        </flux:callout>
    @else
        <div class="flex flex-wrap items-end gap-3 rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:input type="date" wire:model.live="date" label="التاريخ" class="latin-numerals max-w-48" data-test="report-date" />

            <flux:select wire:model.live="shiftId" label="الدوام" class="max-w-48" data-test="report-shift">
                <flux:select.option value="">كل الدوامات</flux:select.option>
                @foreach ($this->shifts as $shift)
                    <flux:select.option :value="$shift->id">{{ $shift->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:select wire:model.live="courseCircleId" label="الحلقة" class="max-w-56" data-test="report-circle">
                @foreach ($this->courseCircles as $courseCircle)
                    <flux:select.option :value="$courseCircle->id">{{ $courseCircle->circle->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:select wire:model.live="mode" label="الترتيب" class="max-w-40" data-test="report-mode">
                <flux:select.option value="daily">اليوم</flux:select.option>
                <flux:select.option value="cumulative">تراكمي</flux:select.option>
            </flux:select>

            <div class="flex flex-1 items-center justify-end gap-2">
                @if ($hijri = HijriDate::long(Carbon::parse($this->date)))
                    <flux:badge color="zinc" class="latin-numerals">{{ $hijri }}</flux:badge>
                @endif
            </div>
        </div>

        @if ($this->circleReport)
            @php($report = $this->circleReport)

            <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
                <div class="flex flex-wrap items-center justify-between gap-2 border-b border-sand-200 p-4 dark:border-zinc-700">
                    <flux:heading size="lg">تقرير {{ $report['variables']['circle_name'] }} — {{ $report['variables']['date'] }}</flux:heading>

                    <flux:button
                        size="sm"
                        icon="printer"
                        variant="primary"
                        target="_blank"
                        :href="route('reports.print.circle', ['courseCircle' => $this->selectedCircle, 'date' => $this->date])"
                        data-test="print-circle-report"
                    >
                        طباعة / PDF
                    </flux:button>
                </div>

                <div class="grid gap-4 p-4 sm:grid-cols-3 xl:grid-cols-6">
                    <x-stat-card label="حاضر" :value="$report['variables']['present']" />
                    <x-stat-card label="غائب" :value="$report['variables']['absent']" tone="danger" />
                    <x-stat-card label="متأخّر" :value="$report['variables']['late']" tone="gold" />
                    <x-stat-card label="مأذون" :value="$report['variables']['excused']" tone="ink" />
                    <x-stat-card label="النسبة" :value="$report['variables']['rate']" tone="gold" />
                    <x-stat-card label="الترتيب اليومي" :value="$report['variables']['daily_rank']" tone="ink" />
                </div>

                <div class="grid gap-4 border-t border-sand-200 p-4 sm:grid-cols-2 dark:border-zinc-700">
                    @foreach ([
                        'الحاضرون' => $report['lists']['present'],
                        'الغائبون' => $report['lists']['absent'],
                        'المتأخّرون' => $report['lists']['late'],
                        'المأذونون' => $report['lists']['excused'],
                    ] as $label => $names)
                        <div>
                            <flux:heading size="sm">{{ $label }} ({{ count($names) }})</flux:heading>
                            <flux:text size="sm" class="mt-1">{{ $names === [] ? '—' : implode('، ', $names) }}</flux:text>
                        </div>
                    @endforeach
                </div>
            </div>
        @endif

        @if ($this->pointsReport)
            @php($points = $this->pointsReport)

            <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
                <div class="flex flex-wrap items-end justify-between gap-3 border-b border-sand-200 p-4 dark:border-zinc-700">
                    <div class="flex flex-1 flex-wrap items-end gap-3">
                        <flux:heading size="lg" class="w-full">
                            نقاط {{ $points['courseCircle']->circle->name }}
                        </flux:heading>

                        <flux:select wire:model.live="range" label="المدى" class="max-w-40" data-test="points-range">
                            @foreach (DateRange::options() as $value => $label)
                                <flux:select.option :value="$value">{{ $label }}</flux:select.option>
                            @endforeach
                        </flux:select>

                        @if ($this->range === DateRange::CUSTOM)
                            <flux:input type="date" wire:model.live="rangeFrom" label="من" class="latin-numerals max-w-44" />
                            <flux:input type="date" wire:model.live="rangeTo" label="إلى" class="latin-numerals max-w-44" />
                        @else
                            <flux:badge color="zinc" class="latin-numerals mb-2">
                                {{ $points['range']->from }} → {{ $points['range']->to }}
                            </flux:badge>
                        @endif
                    </div>

                    <flux:button
                        size="sm"
                        icon="printer"
                        variant="primary"
                        target="_blank"
                        :href="route('reports.print.points', [
                            'courseCircle' => $this->selectedCircle,
                            'range' => $this->range,
                            'from' => $this->rangeFrom,
                            'to' => $this->rangeTo,
                        ])"
                        data-test="print-points-report"
                    >
                        طباعة / PDF
                    </flux:button>
                </div>

                @if ($points['rows']->isEmpty())
                    <flux:text class="p-6 text-center">لا يوجد طلاب مسجَّلون في هذه الحلقة.</flux:text>
                @else
                    <flux:table>
                        <flux:table.columns>
                            <flux:table.column>#</flux:table.column>
                            <flux:table.column>الطالب</flux:table.column>
                            <flux:table.column>القرآن</flux:table.column>
                            <flux:table.column>الحديث</flux:table.column>
                            <flux:table.column>المتون</flux:table.column>
                            <flux:table.column>الحضور</flux:table.column>
                            <flux:table.column>تقديرية</flux:table.column>
                            <flux:table.column>المجموع</flux:table.column>
                        </flux:table.columns>

                        <flux:table.rows>
                            @foreach ($points['rows'] as $row)
                                <flux:table.row :key="'points-'.$row['student']->id">
                                    <flux:table.cell class="latin-numerals">
                                        <flux:badge size="sm" :color="match ($row['rank']) { 1 => 'amber', 2, 3 => 'green', default => 'zinc' }">
                                            {{ $row['rank'] }}
                                        </flux:badge>
                                    </flux:table.cell>
                                    <flux:table.cell>{{ $row['student']->full_name }}</flux:table.cell>
                                    @foreach (['quran', 'hadith', 'mutun', 'attendance', 'manual'] as $source)
                                        <flux:table.cell class="latin-numerals">{{ $row[$source] }}</flux:table.cell>
                                    @endforeach
                                    <flux:table.cell class="latin-numerals font-semibold">{{ $row['total'] }}</flux:table.cell>
                                </flux:table.row>
                            @endforeach
                        </flux:table.rows>
                    </flux:table>
                @endif
            </div>
        @endif

        @if ($this->selectedShift)
            <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
                <div class="flex flex-wrap items-center justify-between gap-2 border-b border-sand-200 p-4 dark:border-zinc-700">
                    <flux:heading size="lg">
                        ترتيب حلقات {{ $this->selectedShift->name }} — {{ $this->mode === 'cumulative' ? 'تراكمي' : 'اليوم' }}
                    </flux:heading>

                    <flux:button
                        size="sm"
                        icon="printer"
                        variant="ghost"
                        target="_blank"
                        :href="route('reports.print.shift', ['shift' => $this->selectedShift, 'date' => $this->date, 'mode' => $this->mode])"
                        data-test="print-shift-report"
                    >
                        طباعة / PDF
                    </flux:button>
                </div>

                @if ($this->ranking->isEmpty())
                    <flux:text class="p-6 text-center">لا توجد حلقات في هذا الدوام.</flux:text>
                @else
                    <flux:table>
                        <flux:table.columns>
                            <flux:table.column>#</flux:table.column>
                            <flux:table.column>الحلقة</flux:table.column>
                            <flux:table.column>حاضر</flux:table.column>
                            <flux:table.column>غائب</flux:table.column>
                            <flux:table.column>متأخّر</flux:table.column>
                            <flux:table.column>مأذون</flux:table.column>
                            <flux:table.column>النسبة</flux:table.column>
                            <flux:table.column>المسار</flux:table.column>
                        </flux:table.columns>

                        <flux:table.rows>
                            @foreach ($this->ranking as $row)
                                <flux:table.row :key="$row->id">
                                    <flux:table.cell class="latin-numerals">
                                        @php($rank = $this->mode === 'cumulative' ? $row->stat?->overall_rank_in_shift : $row->stat?->daily_rank_in_shift)
                                        @if ($rank)
                                            <flux:badge size="sm" :color="$rank === 1 ? 'amber' : 'zinc'">{{ $rank }}</flux:badge>
                                        @else
                                            —
                                        @endif
                                    </flux:table.cell>
                                    <flux:table.cell>{{ $row->circle->name }}</flux:table.cell>
                                    <flux:table.cell class="latin-numerals">{{ $row->stat?->present ?? '—' }}</flux:table.cell>
                                    <flux:table.cell class="latin-numerals">{{ $row->stat?->absent ?? '—' }}</flux:table.cell>
                                    <flux:table.cell class="latin-numerals">{{ $row->stat?->late ?? '—' }}</flux:table.cell>
                                    <flux:table.cell class="latin-numerals">{{ $row->stat?->excused ?? '—' }}</flux:table.cell>
                                    <flux:table.cell>
                                        <x-attendance-rate :rate="$row->stat?->attendance_rate" show-bar />
                                    </flux:table.cell>
                                    <flux:table.cell>
                                        <x-charts.sparkline :values="$row->recent_rates" :max="100" />
                                    </flux:table.cell>
                                </flux:table.row>
                            @endforeach
                        </flux:table.rows>
                    </flux:table>
                @endif
            </div>
        @endif
    @endif
</div>
