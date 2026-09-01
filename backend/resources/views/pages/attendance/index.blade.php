<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\SessionStatus;
use App\Enums\Weekday;
use App\Models\CourseCircle;
use App\Queries\AttendanceBoardQuery;
use App\Support\HijriDate;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

new #[Title('التفقّد')] class extends Component {
    use InteractsWithInstitute;

    #[Url]
    public string $date = '';

    #[Url]
    public string $shiftId = '';

    public function mount(): void
    {
        $this->requireInstitute();

        if ($this->date === '') {
            $this->date = Carbon::today()->toDateString();
        }
    }

    public function today(): void
    {
        $this->date = Carbon::today()->toDateString();
    }

    public function shiftDay(int $days): void
    {
        $this->date = Carbon::parse($this->date)->addDays($days)->toDateString();
    }

    private function board(): AttendanceBoardQuery
    {
        return app(AttendanceBoardQuery::class);
    }

    #[Computed]
    public function weekday(): Weekday
    {
        return Weekday::from(Carbon::parse($this->date)->dayOfWeek);
    }

    #[Computed]
    public function hijri(): ?string
    {
        return HijriDate::long(Carbon::parse($this->date));
    }

    /**
     * @return Collection<int, \App\Models\Shift>
     */
    #[Computed]
    public function shifts(): Collection
    {
        return $this->board()->shifts($this->currentCourse);
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function rows(): Collection
    {
        return $this->board()->rows(
            $this->currentCourse,
            $this->date,
            $this->shiftId === '' ? null : (int) $this->shiftId,
        );
    }

    #[Computed]
    public function openedCount(): int
    {
        return $this->rows->whereNotNull('session_status')->count();
    }

    #[Computed]
    public function dayRate(): ?float
    {
        return app(App\Queries\DashboardOverviewQuery::class)->rateOn($this->currentCourse, $this->date);
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="التفقّد" :subheading="$this->currentCourse?->name">
        <x-slot name="actions">
            <flux:button wire:click="shiftDay(-1)" size="sm" variant="ghost" icon="chevron-right">السابق</flux:button>
            <flux:button wire:click="today" size="sm" variant="ghost">اليوم</flux:button>
            <flux:button wire:click="shiftDay(1)" size="sm" variant="ghost" icon-trailing="chevron-left">التالي</flux:button>
        </x-slot>
    </x-page-header>

    @if ($this->currentCourse === null)
        <flux:callout icon="calendar-days" variant="warning">
            <flux:callout.heading>لا توجد دورة جارية</flux:callout.heading>
            <flux:callout.text>فعّل دورة ليبدأ التفقّد.</flux:callout.text>
            <x-slot name="actions">
                <flux:button :href="route('courses.index')" wire:navigate variant="primary" size="sm">إدارة الدورات</flux:button>
            </x-slot>
        </flux:callout>
    @else
        <div class="flex flex-wrap items-end gap-3 rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:input type="date" wire:model.live="date" label="التاريخ" class="latin-numerals max-w-48" data-test="attendance-date" />

            <flux:select wire:model.live="shiftId" label="الدوام" class="max-w-56" data-test="attendance-shift">
                <flux:select.option value="">دوامات هذا اليوم</flux:select.option>
                @foreach ($this->shifts as $shift)
                    <flux:select.option :value="$shift->id">{{ $shift->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="flex flex-1 flex-wrap items-center justify-end gap-2">
                <flux:badge color="zinc">{{ $this->weekday->label() }}</flux:badge>
                @if ($this->hijri)
                    <flux:badge color="zinc" class="latin-numerals">{{ $this->hijri }}</flux:badge>
                @endif
            </div>
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
            <x-stat-card label="حلقات اليوم" :value="$this->rows->count()" />
            <x-stat-card label="الجلسات المفتوحة" :value="$this->openedCount" tone="gold" />
            <x-stat-card label="نسبة حضور اليوم" :value="$this->dayRate !== null ? $this->dayRate.'%' : '—'" tone="ink" />
        </div>

        <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                <flux:heading size="lg">حلقات {{ $this->weekday->label() }}</flux:heading>
            </div>

            @if ($this->rows->isEmpty())
                <flux:text class="p-6 text-center">لا توجد حلقات مداومة في هذا اليوم. اختر دواماً من القائمة للتفقّد الاستدراكي.</flux:text>
            @else
                <flux:table>
                    <flux:table.columns>
                        <flux:table.column>الحلقة</flux:table.column>
                        <flux:table.column>الدوام</flux:table.column>
                        <flux:table.column>الأستاذ</flux:table.column>
                        <flux:table.column>المسجَّلون</flux:table.column>
                        <flux:table.column>الجلسة</flux:table.column>
                        <flux:table.column>النسبة</flux:table.column>
                        <flux:table.column>الترتيب</flux:table.column>
                        <flux:table.column></flux:table.column>
                    </flux:table.columns>

                    <flux:table.rows>
                        @foreach ($this->rows as $row)
                            <flux:table.row :key="$row->id">
                                <flux:table.cell>{{ $row->circle->name }}</flux:table.cell>
                                <flux:table.cell>{{ $row->shift->name }}</flux:table.cell>
                                <flux:table.cell>{{ $row->teachers->pluck('display_name')->join('، ') ?: '—' }}</flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ $row->active_enrollments_count }}</flux:table.cell>
                                <flux:table.cell>
                                    @php($status = $row->session_status ? SessionStatus::from($row->session_status) : null)
                                    <flux:badge
                                        size="sm"
                                        :color="match ($status) {
                                            SessionStatus::Draft => 'amber',
                                            SessionStatus::Completed => 'green',
                                            SessionStatus::Locked => 'zinc',
                                            default => 'zinc',
                                        }"
                                    >
                                        {{ $status?->label() ?? 'لم تُفتح' }}
                                    </flux:badge>
                                </flux:table.cell>
                                <flux:table.cell>
                                    <x-attendance-rate :rate="$row->todayStat?->attendance_rate" />
                                </flux:table.cell>
                                <flux:table.cell class="latin-numerals">
                                    @if ($row->todayStat?->daily_rank_in_shift)
                                        <flux:badge size="sm" :color="$row->todayStat->daily_rank_in_shift === 1 ? 'amber' : 'zinc'">
                                            {{ $row->todayStat->daily_rank_in_shift }}
                                        </flux:badge>
                                    @else
                                        —
                                    @endif
                                </flux:table.cell>
                                <flux:table.cell>
                                    <flux:button
                                        size="sm"
                                        variant="primary"
                                        icon="clipboard-document-check"
                                        :href="route('attendance.take', ['courseCircle' => $row, 'date' => $this->date])"
                                        wire:navigate
                                    >
                                        {{ $row->session_status === null ? 'تفقّد' : 'فتح' }}
                                    </flux:button>
                                </flux:table.cell>
                            </flux:table.row>
                        @endforeach
                    </flux:table.rows>
                </flux:table>
            @endif
        </div>
    @endif
</div>
