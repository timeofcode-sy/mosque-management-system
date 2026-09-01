<?php

use App\Enums\ProgressStatus;
use App\Models\Student;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('ملف الطالب')] class extends Component {
    public Student $student;

    public function mount(Student $student): void
    {
        $this->student = $student->load('guardians', 'personalTraits', 'institute');
    }

    /**
     * كل تسجيلات الطالب عبر الدورات — الحالية والسابقة والمنقول عنها.
     *
     * @return Collection<int, \App\Models\Enrollment>
     */
    #[Computed]
    public function enrollments(): Collection
    {
        return $this->student->enrollments()
            ->with('courseCircle.circle', 'courseCircle.course', 'courseCircle.shift')
            ->orderByDesc('enrolled_on')
            ->get();
    }

    /**
     * @return Collection<int, \App\Models\StudentTransfer>
     */
    #[Computed]
    public function transfers(): Collection
    {
        return $this->student->transfers()
            ->with('fromCourseCircle.circle', 'toCourseCircle.circle', 'performedBy')
            ->orderByDesc('transferred_on')
            ->get();
    }

    /**
     * المحفوظات مجمَّعة بالمنهج.
     *
     * @return Collection<string, Collection<int, \App\Models\StudentCurriculumProgress>>
     */
    #[Computed]
    public function progressByCurriculum(): Collection
    {
        return $this->student->curriculumProgress()
            ->with('curriculumItem.curriculum')
            ->whereIn('status', [ProgressStatus::InProgress, ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->get()
            ->groupBy(fn ($progress) => $progress->curriculumItem->curriculum->name);
    }

    /**
     * @return Collection<int, \App\Models\Attendance>
     */
    #[Computed]
    public function recentAttendances(): Collection
    {
        return $this->student->attendances()
            ->with('attendanceSession.courseCircle.circle')
            ->latest('recorded_at')
            ->limit(20)
            ->get();
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header :heading="$student->full_name" :subheading="$student->institute->name">
        <x-slot name="actions">
            <flux:button :href="route('students.index')" wire:navigate variant="ghost" icon="arrow-right">الطلاب</flux:button>
            <flux:button :href="route('students.edit', $student)" wire:navigate variant="primary" icon="pencil">تعديل</flux:button>
        </x-slot>
    </x-page-header>

    <div class="grid gap-6 lg:grid-cols-3">
        <div class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:heading size="lg">البيانات الأساسية</flux:heading>

            <dl class="mt-4 space-y-3 text-sm">
                @foreach ([
                    'رقم المعرف' => $student->registration_no,
                    'تاريخ التسجيل' => $student->registration_date?->toDateString(),
                    'التاريخ الهجري' => $student->registration_date_hijri,
                    'تاريخ الولادة' => $student->birth_date?->toDateString(),
                    'مكان الولادة' => $student->birth_place,
                    'الجنس' => $student->gender->label(),
                    'الصف الدراسي' => $student->grade_level,
                    'عمل الطالب' => $student->student_job,
                    'الجوال' => $student->phone,
                    'العنوان الأساسي' => $student->permanent_address,
                    'العنوان الحالي' => $student->current_address,
                    'عدد أفراد العائلة' => $student->family_members_count,
                    'الحالة' => $student->status->label(),
                ] as $label => $value)
                    <div class="flex justify-between gap-4">
                        <dt class="text-ink-500 dark:text-zinc-400">{{ $label }}</dt>
                        <dd class="latin-numerals text-end">{{ $value ?: '—' }}</dd>
                    </div>
                @endforeach
            </dl>
        </div>

        <div class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:heading size="lg">أولياء الأمر</flux:heading>

            <div class="mt-4 space-y-4">
                @forelse ($student->guardians as $guardian)
                    <div wire:key="guardian-{{ $guardian->id }}" class="rounded-lg border border-sand-200 p-3 dark:border-zinc-700">
                        <div class="flex items-center gap-2">
                            <flux:heading size="sm">{{ $guardian->full_name }}</flux:heading>
                            <flux:badge size="sm" color="zinc">
                                {{ App\Enums\GuardianRelation::from($guardian->pivot->relation)->label() }}
                            </flux:badge>
                        </div>
                        <flux:text size="sm" class="latin-numerals mt-1">
                            {{ $guardian->occupation ?: '—' }} · {{ $guardian->phone ?: '—' }}
                        </flux:text>
                    </div>
                @empty
                    <flux:text>لم تُسجَّل بيانات ولي الأمر.</flux:text>
                @endforelse
            </div>

            <flux:separator class="my-6" />

            <flux:heading size="lg">الوضع الصحي</flux:heading>
            <flux:text size="sm" class="mt-2">الطالب: {{ $student->student_health_status ?: '—' }}</flux:text>
            <flux:text size="sm" class="mt-1">العائلة: {{ $student->family_health_status ?: '—' }}</flux:text>
        </div>

        <div class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:heading size="lg">الصفات</flux:heading>

            <div class="mt-4 flex flex-wrap gap-2">
                @forelse ($student->personalTraits as $personalTrait)
                    <flux:badge wire:key="trait-{{ $personalTrait->id }}" :color="$personalTrait->polarity === App\Enums\TraitPolarity::Positive ? 'green' : 'amber'">
                        {{ $personalTrait->name }}
                    </flux:badge>
                @empty
                    <flux:text>لم تُسنَد صفات.</flux:text>
                @endforelse
            </div>

            <flux:separator class="my-6" />

            <flux:heading size="lg">ملاحظات</flux:heading>
            <flux:text size="sm" class="mt-2">{{ $student->notes ?: '—' }}</flux:text>
        </div>
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
            <flux:heading size="lg">مسار الحلقات عبر الدورات</flux:heading>
        </div>

        @if ($this->enrollments->isEmpty())
            <flux:text class="p-6 text-center">لم يُسجَّل الطالب في أي حلقة بعد.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الدورة</flux:table.column>
                    <flux:table.column>الحلقة</flux:table.column>
                    <flux:table.column>الدوام</flux:table.column>
                    <flux:table.column>من</flux:table.column>
                    <flux:table.column>إلى</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->enrollments as $enrollment)
                        <flux:table.row :key="$enrollment->id">
                            <flux:table.cell>{{ $enrollment->courseCircle->course->name }}</flux:table.cell>
                            <flux:table.cell>{{ $enrollment->courseCircle->circle->name }}</flux:table.cell>
                            <flux:table.cell>{{ $enrollment->courseCircle->shift->name }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $enrollment->enrolled_on?->toDateString() ?? '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $enrollment->left_on?->toDateString() ?? '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $enrollment->status->label() }}</flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    @if ($this->transfers->isNotEmpty())
        <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                <flux:heading size="lg">سجل النقل</flux:heading>
            </div>

            <flux:table>
                <flux:table.columns>
                    <flux:table.column>التاريخ</flux:table.column>
                    <flux:table.column>من</flux:table.column>
                    <flux:table.column>إلى</flux:table.column>
                    <flux:table.column>السبب</flux:table.column>
                    <flux:table.column>نفّذها</flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->transfers as $transfer)
                        <flux:table.row :key="$transfer->id">
                            <flux:table.cell class="latin-numerals">{{ $transfer->transferred_on->toDateString() }}</flux:table.cell>
                            <flux:table.cell>{{ $transfer->fromCourseCircle?->circle->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $transfer->toCourseCircle?->circle->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $transfer->reason ?: '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $transfer->performedBy?->name ?? '—' }}</flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        </div>
    @endif

    <div class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
        <flux:heading size="lg">المحفوظات</flux:heading>

        @if ($this->progressByCurriculum->isEmpty())
            <flux:text class="mt-4">لم تُسجَّل محفوظات بعد.</flux:text>
        @else
            <div class="mt-4 flex flex-col gap-6">
                @foreach ($this->progressByCurriculum as $curriculumName => $entries)
                    <div wire:key="progress-{{ $loop->index }}">
                        <flux:heading size="sm">{{ $curriculumName }}</flux:heading>

                        <div class="mt-2 flex flex-wrap gap-2">
                            @foreach ($entries as $progress)
                                <flux:badge size="sm" :color="$progress->status === ProgressStatus::Mastered ? 'green' : 'zinc'">
                                    {{ $progress->curriculumItem->name }}
                                </flux:badge>
                            @endforeach
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </div>

    @if ($this->recentAttendances->isNotEmpty())
        <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                <flux:heading size="lg">آخر سجلات الحضور</flux:heading>
            </div>

            <flux:table>
                <flux:table.columns>
                    <flux:table.column>التاريخ</flux:table.column>
                    <flux:table.column>الحلقة</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->recentAttendances as $attendance)
                        <flux:table.row :key="$attendance->id">
                            <flux:table.cell class="latin-numerals">{{ $attendance->attendanceSession->session_date->toDateString() }}</flux:table.cell>
                            <flux:table.cell>{{ $attendance->attendanceSession->courseCircle->circle->name }}</flux:table.cell>
                            <flux:table.cell>{{ $attendance->status->label() }}</flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        </div>
    @endif
</div>
