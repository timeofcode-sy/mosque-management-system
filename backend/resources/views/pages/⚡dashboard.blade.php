<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\EnrollmentStatus;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('لوحة المعلومات')] class extends Component {
    use InteractsWithInstitute;

    /**
     * حلقات الدورة الجارية مرتّبة بالدوام، مع عدد المسجَّلين في كل حلقة.
     *
     * @return Collection<int, \App\Models\CourseCircle>
     */
    #[Computed]
    public function courseCircles(): Collection
    {
        if ($this->currentCourse === null) {
            return new Collection;
        }

        return $this->currentCourse->courseCircles()
            ->with(['circle', 'shift.days', 'teachers'])
            ->withCount(['enrollments as active_enrollments_count' => fn ($query) => $query->where('status', EnrollmentStatus::Active)])
            ->get()
            ->sortBy(fn ($courseCircle) => [$courseCircle->shift->sort_order, $courseCircle->circle->sort_order])
            ->values();
    }

    #[Computed]
    public function studentsCount(): int
    {
        return Student::query()->where('institute_id', $this->institute?->id)->count();
    }

    #[Computed]
    public function teachersCount(): int
    {
        return Teacher::query()->where('institute_id', $this->institute?->id)->count();
    }

    #[Computed]
    public function enrolledCount(): int
    {
        if ($this->currentCourse === null) {
            return 0;
        }

        return Enrollment::query()
            ->where('status', EnrollmentStatus::Active)
            ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $this->currentCourse->id))
            ->count();
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="لوحة المعلومات" :subheading="$this->institute?->name" />

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
            <x-stat-card label="الطلاب في المعهد" :value="$this->studentsCount" />
            <x-stat-card label="المسجَّلون في الدورة الجارية" :value="$this->enrolledCount" tone="gold" />
            <x-stat-card label="الحلقات العاملة" :value="$this->courseCircles->count()" />
            <x-stat-card label="الأساتذة" :value="$this->teachersCount" tone="ink" />
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
                            </flux:table.row>
                        @endforeach
                    </flux:table.rows>
                </flux:table>
            @endif
        </div>
    @endif
</div>
