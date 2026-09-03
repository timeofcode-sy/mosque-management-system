<?php

use App\Concerns\InteractsWithInstitute;
use App\Queries\DashboardOverviewQuery;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('لوحة المعلومات')] class extends Component {
    use InteractsWithInstitute;

    /**
     * طبقة القراءة تُحلّ من الحاوية لا بالحقن في المُنشئ — فمكوّن Livewire يُعاد
     * بناؤه مع كل طلب، والمُنشئ ليس موضع اعتماد.
     */
    private function overview(): DashboardOverviewQuery
    {
        return app(DashboardOverviewQuery::class);
    }

    /**
     * @return array{students: int, enrolled: int, circles: int, teachers: int}
     */
    #[Computed]
    public function counters(): array
    {
        return $this->overview()->counters($this->institute, $this->currentCourse);
    }

    /**
     * @return Collection<int, \App\Models\CourseCircle>
     */
    #[Computed]
    public function courseCircles(): Collection
    {
        return $this->overview()->circles($this->currentCourse);
    }

    /**
     * @return Collection<int, array{date: string, rate: float, sessions: int}>
     */
    #[Computed]
    public function trend(): Collection
    {
        return $this->overview()->trend($this->currentCourse);
    }

    #[Computed]
    public function todayRate(): ?float
    {
        return $this->overview()->rateOn($this->currentCourse, Carbon::today()->toDateString());
    }

    /**
     * @return array{present: int, absent: int, late: int, excused: int}
     */
    #[Computed]
    public function statusBreakdown(): array
    {
        return $this->overview()->statusBreakdown($this->currentCourse);
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="لوحة المعلومات" :subheading="$this->institute?->name">
        <x-slot name="actions">
            <flux:button :href="route('attendance.index')" wire:navigate variant="primary" icon="clipboard-document-check">تفقّد اليوم</flux:button>
        </x-slot>
    </x-page-header>

    @if ($this->institute === null)
        <x-no-institute />
    @else
        @if ($this->currentCourse === null)
            <flux:callout icon="calendar-days" variant="warning">
                <flux:callout.heading>لا توجد دورة جارية</flux:callout.heading>
                <flux:callout.text>أنشئ دورة وفعّلها ليبدأ التسجيل والتفقّد.</flux:callout.text>
                <x-slot name="actions">
                    <flux:button :href="route('courses.index')" wire:navigate variant="primary" size="sm">إدارة الدورات</flux:button>
                </x-slot>
            </flux:callout>
        @endif

        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <x-stat-card label="الطلاب في المعهد" :value="$this->counters['students']" />
            <x-stat-card label="المسجَّلون في الدورة الجارية" :value="$this->counters['enrolled']" tone="gold" />
            <x-stat-card label="الحلقات العاملة" :value="$this->counters['circles']" />
            <x-stat-card
                label="نسبة حضور اليوم"
                :value="$this->todayRate !== null ? $this->todayRate.'%' : '—'"
                :hint="$this->todayRate === null ? 'لم تُغلق جلسات اليوم بعد' : null"
                tone="ink"
            />
        </div>

        <div class="grid gap-4 lg:grid-cols-3">
            <x-attendance-trend :points="$this->trend" class="lg:col-span-2" />
            <x-attendance-breakdown :breakdown="$this->statusBreakdown" />
        </div>

        <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                <flux:heading size="lg">حلقات {{ $this->currentCourse?->name ?? 'الدورة' }}</flux:heading>
            </div>

            @if ($this->courseCircles->isEmpty())
                <flux:text class="p-6 text-center">لا توجد حلقات مشغَّلة في هذه الدورة بعد.</flux:text>
            @else
                <flux:table>
                    <flux:table.columns>
                        <flux:table.column>الحلقة</flux:table.column>
                        <flux:table.column>الدوام</flux:table.column>
                        <flux:table.column>الأيام</flux:table.column>
                        <flux:table.column>الأستاذ</flux:table.column>
                        <flux:table.column>الطلاب</flux:table.column>
                        <flux:table.column>النسبة التراكمية</flux:table.column>
                        <flux:table.column>الترتيب في الدوام</flux:table.column>
                    </flux:table.columns>

                    <flux:table.rows>
                        @foreach ($this->courseCircles as $courseCircle)
                            <flux:table.row :key="$courseCircle->id">
                                <flux:table.cell>
                                    <flux:link :href="route('circles.show', $courseCircle)" wire:navigate>
                                        {{ $courseCircle->circle->name }}
                                    </flux:link>
                                </flux:table.cell>
                                <flux:table.cell>{{ $courseCircle->shift->name }}</flux:table.cell>
                                <flux:table.cell>{{ implode(' · ', $courseCircle->shift->weekdayLabels()) }}</flux:table.cell>
                                <flux:table.cell>{{ $courseCircle->teachers->pluck('display_name')->join('، ') ?: '—' }}</flux:table.cell>
                                <flux:table.cell class="latin-numerals">{{ $courseCircle->active_enrollments_count }}</flux:table.cell>
                                <flux:table.cell class="latin-numerals">
                                    <x-attendance-rate :rate="$courseCircle->standing?->attendance_rate" />
                                </flux:table.cell>
                                <flux:table.cell class="latin-numerals">
                                    @if ($courseCircle->standing?->overall_rank_in_shift)
                                        <flux:badge size="sm" :color="$courseCircle->standing->overall_rank_in_shift === 1 ? 'amber' : 'zinc'">
                                            {{ $courseCircle->standing->overall_rank_in_shift }}
                                        </flux:badge>
                                    @else
                                        —
                                    @endif
                                </flux:table.cell>
                            </flux:table.row>
                        @endforeach
                    </flux:table.rows>
                </flux:table>
            @endif
        </div>
    @endif
</div>
