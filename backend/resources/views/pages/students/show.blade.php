<?php

use App\Actions\BuildStudentProgressMap;
use App\Actions\SaveStudentCurriculumProgress;
use App\Enums\ProgressStatus;
use App\Models\Attendance;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\StudentTransfer;
use App\Queries\InstituteCatalogQuery;
use App\Queries\StudentProfileQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('ملف الطالب')] class extends Component
{
    public Student $student;

    public ?int $progressItemId = null;

    public string $progressStatus = '';

    public int $progressPercent = 0;

    public string $progressNotes = '';

    public function mount(Student $student): void
    {
        $this->student = $student->load('guardians', 'personalTraits', 'institute', 'customFieldValues.customField');
    }

    private function profile(): StudentProfileQuery
    {
        return app(StudentProfileQuery::class);
    }

    /**
     * قيم الواصفات المخصّصة الفعّالة للطالب، جاهزة للعرض كتسمية وقيمة.
     *
     * @return Collection<int, array{label: string, value: string}>
     */
    #[Computed]
    public function customFieldEntries(): Collection
    {
        return $this->student->customFieldValues
            ->filter(fn ($entry) => $entry->customField !== null && $entry->customField->is_active)
            ->sortBy(fn ($entry) => $entry->customField->sort_order)
            ->map(fn ($entry) => [
                'label' => $entry->customField->label,
                'value' => is_array($entry->value) ? implode('، ', $entry->value) : (string) ($entry->value ?? '—'),
            ])
            ->values();
    }

    /**
     * @return Collection<int, Enrollment>
     */
    #[Computed]
    public function enrollments(): Collection
    {
        return $this->profile()->enrollments($this->student);
    }

    /**
     * @return Collection<int, StudentTransfer>
     */
    #[Computed]
    public function transfers(): Collection
    {
        return $this->profile()->transfers($this->student);
    }

    /**
     * المناهج المتاحة للمعهد ببنودها — لوح تحرير الإنجاز.
     *
     * @return Collection<int, Curriculum>
     */
    #[Computed]
    public function curricula(): Collection
    {
        return app(InstituteCatalogQuery::class)->curricula($this->student->institute);
    }

    /**
     * إنجاز الطالب مفهرساً ببند المنهج — للقراءة السريعة في الشبكة.
     *
     * @return Collection<int, StudentCurriculumProgress>
     */
    #[Computed]
    public function progressByItem(): Collection
    {
        return $this->student->curriculumProgress()->get()->keyBy('curriculum_item_id');
    }

    #[Computed]
    public function editingItem(): ?CurriculumItem
    {
        return $this->progressItemId === null
            ? null
            : $this->curricula->flatMap->items->firstWhere('id', $this->progressItemId);
    }

    public function editProgress(CurriculumItem $curriculumItem): void
    {
        $existing = $this->progressByItem->get($curriculumItem->id);

        $this->progressItemId = $curriculumItem->id;
        $this->progressStatus = $existing?->status->value ?? ProgressStatus::InProgress->value;
        $this->progressPercent = $existing?->percent ?? 0;
        $this->progressNotes = (string) $existing?->notes;
        $this->resetValidation();

        unset($this->editingItem);

        Flux::modal('curriculum-progress')->show();
    }

    public function saveProgress(): void
    {
        $item = $this->editingItem;

        if ($item === null) {
            return;
        }

        $this->validate([
            'progressStatus' => ['required', Rule::enum(ProgressStatus::class)],
            'progressPercent' => ['integer', 'between:0,100'],
            'progressNotes' => ['nullable', 'string', 'max:1000'],
        ], attributes: ['progressStatus' => 'الحالة', 'progressPercent' => 'النسبة']);

        app(SaveStudentCurriculumProgress::class)->handle(
            $this->student,
            $item,
            ['status' => $this->progressStatus, 'percent' => $this->progressPercent, 'notes' => $this->progressNotes],
            auth()->user(),
        );

        unset($this->progressByItem);

        Flux::modal('curriculum-progress')->close();
        Flux::toast(variant: 'success', text: 'حُدّث الإنجاز.');
    }

    /**
     * @return Collection<int, Attendance>
     */
    #[Computed]
    public function recentAttendances(): Collection
    {
        return $this->profile()->recentAttendances($this->student);
    }

    /**
     * @return array{present: int, absent: int, late: int, excused: int, total: int, rate: float|null}
     */
    #[Computed]
    public function summary(): array
    {
        return $this->profile()->attendanceSummary($this->student);
    }

    /**
     * @return Collection<int, array{date: string, rate: float, sessions: int}>
     */
    #[Computed]
    public function trend(): Collection
    {
        return $this->profile()->attendanceTrend($this->student);
    }

    /**
     * @return array<string, mixed>
     */
    #[Computed]
    public function progressMap(): array
    {
        return app(BuildStudentProgressMap::class)->handle($this->student);
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header :heading="$student->full_name" :subheading="$student->institute->name">
        <x-slot name="actions">
            <flux:button :href="route('students.index')" wire:navigate variant="ghost" icon="arrow-right">الطلاب</flux:button>
            <flux:button :href="route('reports.print.student', $student)" target="_blank" variant="ghost" icon="printer" data-test="print-student-report">تقرير</flux:button>
            <flux:button :href="route('students.edit', $student)" wire:navigate variant="primary" icon="pencil">تعديل</flux:button>
        </x-slot>
    </x-page-header>

    <div class="grid gap-4 sm:grid-cols-3 xl:grid-cols-5">
        <x-stat-card label="حاضر" :value="$this->summary['present']" />
        <x-stat-card label="غائب" :value="$this->summary['absent']" tone="danger" />
        <x-stat-card label="متأخّر" :value="$this->summary['late']" tone="gold" />
        <x-stat-card label="مأذون" :value="$this->summary['excused']" tone="ink" />
        <x-stat-card
            label="نسبة الحضور"
            :value="$this->summary['rate'] !== null ? $this->summary['rate'].'%' : '—'"
            :hint="$this->summary['total'] > 0 ? $this->summary['total'].' جلسة' : null"
            tone="gold"
        />
    </div>

    <x-attendance-trend :points="$this->trend" heading="منحنى حضور الطالب — آخر ٣٠ يوماً" />

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
            <div class="flex justify-center">
                @if ($student->photo_path)
                    <img
                        src="{{ Storage::url($student->photo_path) }}"
                        alt="صورة {{ $student->full_name }}"
                        class="h-28 w-28 rounded-full border border-sand-200 object-cover dark:border-zinc-700"
                    />
                @else
                    <div class="flex h-28 w-28 items-center justify-center rounded-full border border-dashed border-sand-300 bg-sand-50 text-ink-500 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-500">
                        <flux:icon name="user" class="size-10" />
                    </div>
                @endif
            </div>

            <flux:separator class="my-6" />

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

            @if ($this->customFieldEntries->isNotEmpty())
                <flux:separator class="my-6" />

                <flux:heading size="lg">الواصفات المخصّصة</flux:heading>

                <dl class="mt-4 space-y-3 text-sm">
                    @foreach ($this->customFieldEntries as $entry)
                        <div class="flex justify-between gap-4">
                            <dt class="text-ink-500 dark:text-zinc-400">{{ $entry['label'] }}</dt>
                            <dd class="text-end">{{ $entry['value'] ?: '—' }}</dd>
                        </div>
                    @endforeach
                </dl>
            @endif

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
        <div class="flex flex-wrap items-baseline justify-between gap-3">
            <flux:heading size="lg">خريطة تقدّم الحفظ في المصحف</flux:heading>

            <flux:text size="sm" class="latin-numerals text-ink-500 dark:text-zinc-400">
                {{ $this->progressMap['memorized_ayahs'] }} / {{ App\Support\Quran::TOTAL_AYAHS }} آية ·
                {{ $this->progressMap['completed_surahs'] }} سورة مكتملة ·
                {{ round($this->progressMap['overall_ratio'] * 100, 1) }}%
            </flux:text>
        </div>

        @if ($this->progressMap['memorized_ayahs'] === 0)
            <flux:text class="mt-4">لم تُسجَّل مدَيات حفظ بعد — الخريطة تُبنى من سجلّات الحفظ (from_surah إلى to_surah).</flux:text>
        @endif

        <x-surah-map :surahs="$this->progressMap['surahs']" class="mt-4" />
    </div>

    <div class="rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
        <div class="flex flex-wrap items-baseline justify-between gap-3">
            <flux:heading size="lg">المحفوظات وتقدّم المناهج</flux:heading>
            <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">اضغط البند لتحديث حالته ونسبته.</flux:text>
        </div>

        <div class="mt-4 flex flex-col gap-6">
            @foreach ($this->curricula as $curriculum)
                <div wire:key="curriculum-{{ $curriculum->id }}">
                    <flux:heading size="sm">{{ $curriculum->name }}</flux:heading>

                    <div class="mt-2 flex flex-wrap gap-2">
                        @forelse ($curriculum->items as $item)
                            @php($progress = $this->progressByItem->get($item->id))

                            <flux:badge
                                wire:key="progress-item-{{ $item->id }}"
                                size="sm"
                                :color="match ($progress?->status) {
                                    ProgressStatus::Mastered => 'green',
                                    ProgressStatus::Memorized => 'lime',
                                    ProgressStatus::InProgress => 'amber',
                                    default => 'zinc',
                                }"
                            >
                                <button
                                    type="button"
                                    class="cursor-pointer"
                                    wire:click="editProgress('{{ $item->uuid }}')"
                                    data-test="progress-item-{{ $item->id }}"
                                >
                                    {{ $item->name }}
                                    @if ($progress && $progress->percent > 0 && $progress->percent < 100)
                                        <span class="latin-numerals"> · {{ $progress->percent }}%</span>
                                    @endif
                                    @if ($progress && (float) $progress->points > 0)
                                        <span class="latin-numerals"> · {{ rtrim(rtrim(number_format((float) $progress->points, 2, '.', ''), '0'), '.') }} نقطة</span>
                                    @endif
                                </button>
                            </flux:badge>
                        @empty
                            <flux:text size="sm">لا توجد بنود في هذا المنهج.</flux:text>
                        @endforelse
                    </div>
                </div>
            @endforeach
        </div>
    </div>

    <flux:modal name="curriculum-progress" class="w-full max-w-lg">
        @if ($this->editingItem)
            <form wire:submit="saveProgress" class="space-y-6">
                <flux:heading size="lg">{{ $this->editingItem->name }}</flux:heading>

                <flux:select wire:model.live="progressStatus" label="الحالة" data-test="progress-status">
                    @foreach (ProgressStatus::options() as $value => $label)
                        <flux:select.option :value="$value">{{ $label }}</flux:select.option>
                    @endforeach
                </flux:select>

                @if ($progressStatus === ProgressStatus::InProgress->value)
                    <flux:input
                        wire:model="progressPercent"
                        type="number" min="1" max="99"
                        label="النسبة المنجَزة %"
                        class="latin-numerals"
                        data-test="progress-percent"
                    />
                @endif

                <flux:textarea wire:model="progressNotes" label="ملاحظات" rows="2" />

                <div class="flex gap-2">
                    <flux:button type="submit" variant="primary" data-test="save-progress">حفظ</flux:button>
                    <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                </div>
            </form>
        @endif
    </flux:modal>

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
