<?php

use App\Actions\CompleteAttendanceSession;
use App\Actions\LockAttendanceSession;
use App\Actions\OpenAttendanceSession;
use App\Actions\ReopenAttendanceSession;
use App\Actions\TakeAttendance;
use App\Concerns\InteractsWithInstitute;
use App\Enums\AttendanceStatus;
use App\Enums\NotePolarity;
use App\Enums\SessionStatus;
use App\Enums\Weekday;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Queries\AttendanceSessionQuery;
use App\Support\AttendanceSettings;
use App\Support\LateMinutes;
use Flux\Flux;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

new #[Title('تفقّد الحلقة')] class extends Component {
    use InteractsWithInstitute;

    public CourseCircle $courseCircle;

    #[Url]
    public string $date = '';

    /** @var array<int, array{status: string, late_minutes: int|string|null, note: string|null, note_polarity: string|null}> */
    public array $rows = [];

    /** @var array<int, array{status: string, late_minutes: int|string|null, note: string|null}> */
    public array $teacherRows = [];

    /** الطالب المفتوحة ملاحظتُه في المودال. */
    public ?int $noteStudentId = null;

    public function mount(CourseCircle $courseCircle): void
    {
        $this->requireInstitute();

        $this->courseCircle = $courseCircle->load('circle', 'course', 'shift.days', 'teachers');

        if ($this->date === '') {
            $this->date = Carbon::today()->toDateString();
        }

        $this->openSession();
    }

    /**
     * فتح الجلسة يُنشئها إن لم تكن، ويبذر صفوف الطلاب المسجَّلين في ذلك التاريخ.
     */
    public function openSession(): void
    {
        app(OpenAttendanceSession::class)->handle($this->courseCircle, $this->date, auth()->user());

        unset($this->session, $this->attendances, $this->teacherAttendances);

        $this->loadRows();
    }

    public function updatedDate(): void
    {
        $this->openSession();
    }

    private function query(): AttendanceSessionQuery
    {
        return app(AttendanceSessionQuery::class);
    }

    #[Computed]
    public function session(): ?AttendanceSession
    {
        return $this->query()->session($this->courseCircle, $this->date);
    }

    /**
     * @return Collection<int, \App\Models\Attendance>
     */
    #[Computed]
    public function attendances(): Collection
    {
        return $this->query()->attendances($this->session);
    }

    /**
     * @return Collection<int, \App\Models\Teacher>
     */
    #[Computed]
    public function teachers(): Collection
    {
        return $this->query()->assignedTeachers($this->courseCircle, $this->date);
    }

    /**
     * أرقام الشريط العلوي محسوبة من حالة الشاشة لا من قاعدة البيانات،
     * فتتحرّك مع كل ضغطة قبل الحفظ.
     *
     * @return array<string, int>
     */
    #[Computed]
    public function tally(): array
    {
        $counts = array_fill_keys(array_column(AttendanceStatus::cases(), 'value'), 0);

        foreach ($this->rows as $row) {
            if (isset($counts[$row['status']])) {
                $counts[$row['status']]++;
            }
        }

        return $counts;
    }

    #[Computed]
    public function liveRate(): ?float
    {
        $counts = $this->tally;
        $countable = array_sum($counts) - $counts[AttendanceStatus::Excused->value];

        if ($countable <= 0) {
            return null;
        }

        $attended = $counts[AttendanceStatus::Present->value] + $counts[AttendanceStatus::Late->value];

        return round($attended / $countable * 100, 1);
    }

    /**
     * القفل وإعادة الفتح للمشرف وحده — الأستاذ لا يملك attendance.lock في البذرة.
     */
    #[Computed]
    public function canLock(): bool
    {
        return (bool) auth()->user()?->can('attendance.lock');
    }

    /**
     * التصحيح الرجعي فعلٌ مقصود لا سهو: الجلسة المكتملة لا تُعدَّل إلا بـ attendance.amend.
     */
    #[Computed]
    public function canAmend(): bool
    {
        return (bool) auth()->user()?->can('attendance.amend');
    }

    #[Computed]
    public function editable(): bool
    {
        return match ($this->session?->status) {
            SessionStatus::Locked => false,
            SessionStatus::Completed => $this->canAmend,
            default => true,
        };
    }

    #[Computed]
    public function excusedToday(): array
    {
        return $this->query()->excusedStudentIds($this->courseCircle, $this->date);
    }

    #[Computed]
    public function weekdayNotice(): ?string
    {
        $weekday = Weekday::from(Carbon::parse($this->date)->dayOfWeek);

        if (in_array($weekday->value, $this->courseCircle->shift->weekdays(), true)) {
            return null;
        }

        return "{$weekday->label()} ليس من أيام دوام {$this->courseCircle->shift->name} — هذا تفقّد استدراكي.";
    }

    public function markAll(string $status): void
    {
        if (! AttendanceStatus::tryFrom($status) || ! $this->editable) {
            return;
        }

        foreach (array_keys($this->rows) as $studentId) {
            $this->rows[$studentId]['status'] = $status;
        }
    }

    public function setStatus(int $studentId, string $status): void
    {
        if (! AttendanceStatus::tryFrom($status) || ! isset($this->rows[$studentId]) || ! $this->editable) {
            return;
        }

        $this->rows[$studentId]['status'] = $status;

        if ($status === AttendanceStatus::Late->value && blank($this->rows[$studentId]['late_minutes'])) {
            $this->rows[$studentId]['late_minutes'] = $this->autoLateMinutes;
        }
    }

    /**
     * دقائق التأخير المقترحة الآن — تُملأ في الحقل لحظةَ الضغط على «متأخر» فيراها
     * الأستاذ قبل الحفظ، ويبقى تعديلها بيده.
     *
     * القيمة نفسها يحسبها الخادم في TakeAttendance لو تُرك الحقل فارغاً؛ فما هنا
     * عرضٌ مبكّر لا مصدرُ حقيقة ثانٍ.
     */
    #[Computed]
    public function autoLateMinutes(): int
    {
        if ($this->session === null) {
            return 0;
        }

        $grace = AttendanceSettings::for($this->institute)->lateGraceMinutes();

        return LateMinutes::afterGrace(LateMinutes::forSession($this->session), $grace) ?? 0;
    }

    public function setTeacherStatus(int $teacherId, string $status): void
    {
        if (! AttendanceStatus::tryFrom($status) || ! isset($this->teacherRows[$teacherId]) || ! $this->editable) {
            return;
        }

        $this->teacherRows[$teacherId]['status'] = $status;
    }

    public function openNote(int $studentId): void
    {
        if (! isset($this->rows[$studentId])) {
            return;
        }

        $this->noteStudentId = $studentId;

        Flux::modal('student-note')->show();
    }

    /**
     * الملاحظة تُحفظ فوراً مع بقية الصفوف حتى لا تضيع بإغلاق المودال دون «حفظ مسودّة».
     */
    public function saveNote(): void
    {
        $this->persist();

        Flux::modal('student-note')->close();
        Flux::toast(variant: 'success', text: 'حُفظت الملاحظة.');
    }

    public function save(): void
    {
        $this->persist();

        Flux::toast(variant: 'success', text: 'حُفظ التفقّد كمسودّة.');
    }

    public function complete(): void
    {
        $this->persist();

        try {
            app(CompleteAttendanceSession::class)->handle($this->session, auth()->user());
        } catch (\RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->session);

        Flux::toast(variant: 'success', text: 'أُغلقت الجلسة وحُدّث ترتيب الحلقة.');
    }

    public function reopen(): void
    {
        if (! $this->canLock) {
            Flux::toast(variant: 'danger', text: 'إعادة فتح الجلسة من صلاحية المشرف.');

            return;
        }

        try {
            app(ReopenAttendanceSession::class)->handle($this->session);
        } catch (\RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->session);

        Flux::toast(variant: 'success', text: 'أُعيد فتح الجلسة للتعديل.');
    }

    public function lock(): void
    {
        if (! $this->canLock) {
            Flux::toast(variant: 'danger', text: 'قفل الجلسة من صلاحية المشرف.');

            return;
        }

        try {
            app(LockAttendanceSession::class)->handle($this->session);
        } catch (\RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->session);

        Flux::toast(variant: 'success', text: 'قُفلت الجلسة نهائياً.');
    }

    /**
     * الكتابة تمرّ بإجراء TakeAttendance — الشاشة لا تكتب في الجداول مباشرة.
     */
    private function persist(): void
    {
        $session = $this->session;

        if ($session === null || ! $this->editable) {
            return;
        }

        try {
            app(TakeAttendance::class)->handle(
                $session,
                $this->rows,
                auth()->user(),
                amend: $session->status === SessionStatus::Completed,
            );

            app(App\Actions\TakeTeacherAttendance::class)->handle($session, $this->teacherRows, auth()->user());
        } catch (\RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->attendances);
    }

    private function loadRows(): void
    {
        $this->rows = $this->attendances
            ->mapWithKeys(fn ($attendance) => [$attendance->student_id => [
                'status' => $attendance->status->value,
                'late_minutes' => $attendance->late_minutes,
                'note' => $attendance->note,
                'note_polarity' => $attendance->note_polarity?->value,
            ]])
            ->all();

        $recorded = $this->query()->teacherAttendances($this->session);

        $this->teacherRows = $this->teachers
            ->mapWithKeys(fn ($teacher) => [$teacher->id => [
                'status' => $recorded->get($teacher->id)?->status->value ?? AttendanceStatus::Present->value,
                'late_minutes' => $recorded->get($teacher->id)?->late_minutes,
                'note' => $recorded->get($teacher->id)?->note,
            ]])
            ->all();
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header
        :heading="'تفقّد · '.$courseCircle->circle->name"
        :subheading="$courseCircle->shift->name.' · '.$courseCircle->course->name"
    >
        <x-slot name="actions">
            <flux:button :href="route('attendance.index', ['date' => $this->date])" wire:navigate variant="ghost" icon="arrow-right">اللوح</flux:button>

            @if ($this->canLock && $this->session?->status === SessionStatus::Completed)
                <flux:button wire:click="reopen" variant="ghost" icon="lock-open" data-test="reopen-session">إعادة فتح</flux:button>
                <flux:button wire:click="lock" variant="ghost" icon="lock-closed" data-test="lock-session">قفل نهائي</flux:button>
            @endif

            @if ($this->editable)
                <flux:button wire:click="save" variant="ghost" icon="bookmark" data-test="save-attendance">حفظ مسودّة</flux:button>
                <flux:button wire:click="complete" variant="primary" icon="check-circle" data-test="complete-attendance">إغلاق الجلسة</flux:button>
            @endif
        </x-slot>
    </x-page-header>

    @if ($this->weekdayNotice)
        <flux:callout icon="exclamation-triangle" variant="warning">
            <flux:callout.text>{{ $this->weekdayNotice }}</flux:callout.text>
        </flux:callout>
    @endif

    @if (! $this->editable)
        <flux:callout icon="lock-closed" variant="secondary">
            <flux:callout.text>
                {{ $this->session?->status === SessionStatus::Locked
                    ? 'هذه الجلسة مقفلة — العرض للقراءة فقط.'
                    : 'هذه الجلسة مكتملة — تعديلها من صلاحية المشرف.' }}
            </flux:callout.text>
        </flux:callout>
    @endif

    <div class="flex flex-wrap items-end gap-3 rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900">
        <flux:input type="date" wire:model.live="date" label="تاريخ الجلسة" class="latin-numerals max-w-48" data-test="session-date" />

        <div class="flex flex-1 flex-wrap items-center justify-end gap-2">
            <flux:badge color="zinc">{{ App\Enums\Weekday::from(Illuminate\Support\Carbon::parse($this->date)->dayOfWeek)->label() }}</flux:badge>
            @if ($hijri = App\Support\HijriDate::long(Illuminate\Support\Carbon::parse($this->date)))
                <flux:badge color="zinc" class="latin-numerals">{{ $hijri }}</flux:badge>
            @endif
            <flux:badge :color="match ($this->session?->status) {
                App\Enums\SessionStatus::Completed => 'green',
                App\Enums\SessionStatus::Locked => 'zinc',
                default => 'amber',
            }">
                {{ $this->session?->status->label() ?? 'مسودّة' }}
            </flux:badge>
        </div>
    </div>

    <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        @foreach (App\Enums\AttendanceStatus::cases() as $status)
            <x-stat-card
                :label="$status->label()"
                :value="$this->tally[$status->value]"
                :tone="match ($status) {
                    App\Enums\AttendanceStatus::Present => 'brand',
                    App\Enums\AttendanceStatus::Absent => 'danger',
                    App\Enums\AttendanceStatus::Late => 'gold',
                    App\Enums\AttendanceStatus::Excused => 'ink',
                }"
            />
        @endforeach

        <x-stat-card label="النسبة" :value="$this->liveRate !== null ? $this->liveRate.'%' : '—'" tone="gold" />
    </div>

    @if ($this->editable && $this->rows !== [])
        <div class="flex flex-wrap items-center gap-2 rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900">
            <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">تعيين سريع للجميع:</flux:text>

            @foreach (App\Enums\AttendanceStatus::cases() as $status)
                <flux:button size="sm" variant="subtle" wire:click="markAll('{{ $status->value }}')" data-test="mark-all-{{ $status->value }}">
                    {{ $status->label() }}
                </flux:button>
            @endforeach
        </div>
    @endif

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
            <flux:heading size="lg">الطلاب</flux:heading>
        </div>

        @if ($this->attendances->isEmpty())
            <flux:text class="p-6 text-center">لا يوجد طلاب مسجَّلون في هذه الحلقة بهذا التاريخ.</flux:text>
        @else
            <div class="divide-y divide-sand-200 dark:divide-zinc-700">
                @foreach ($this->attendances as $attendance)
                    @php
                        $studentId = $attendance->student_id;
                        $polarity = $this->rows[$studentId]['note_polarity'] ?? null;
                        $hasNote = filled($this->rows[$studentId]['note'] ?? null);
                    @endphp

                    <div wire:key="attendance-{{ $studentId }}" class="flex flex-col gap-3 p-4">
                        <div class="flex flex-wrap items-center gap-3">
                            <div class="min-w-48 flex-1">
                                <div class="flex flex-wrap items-center gap-2">
                                    <flux:link :href="route('students.show', $attendance->student)" wire:navigate>
                                        {{ $attendance->student->full_name }}
                                    </flux:link>

                                    @if (in_array($studentId, $this->excusedToday, true))
                                        <flux:badge size="sm" color="blue">إذن مقبول</flux:badge>
                                    @endif
                                </div>
                                <flux:text size="sm" class="latin-numerals text-ink-500 dark:text-zinc-400">
                                    {{ $attendance->student->registration_no ?: '—' }}
                                </flux:text>
                            </div>

                            <x-attendance-picker
                                :name="'rows.'.$studentId.'.status'"
                                :selected="$this->rows[$studentId]['status'] ?? 'present'"
                                :disabled="! $this->editable"
                                :on-select="'setStatus('.$studentId.', %s)'"
                                :test-id="'student-'.$studentId"
                            />

                            @if (($this->rows[$studentId]['status'] ?? null) === App\Enums\AttendanceStatus::Late->value)
                                <flux:input
                                    type="number"
                                    min="0"
                                    max="600"
                                    wire:model="rows.{{ $studentId }}.late_minutes"
                                    placeholder="دقائق"
                                    class="latin-numerals max-w-24"
                                    :disabled="! $this->editable"
                                />
                            @endif

                            {{-- الملاحظة أيقونة تتلوّن بنوعها، فيُعرف من نظرة أيّ الطلاب لهم ملاحظات --}}
                            <flux:button
                                size="sm"
                                variant="subtle"
                                icon="pencil-square"
                                wire:click="openNote({{ $studentId }})"
                                data-test="open-note-{{ $studentId }}"
                                @class([
                                    'text-ink-400 dark:text-zinc-500' => ! $hasNote,
                                    'text-present' => $hasNote && $polarity === App\Enums\NotePolarity::Positive->value,
                                    'text-absent' => $hasNote && $polarity !== App\Enums\NotePolarity::Positive->value,
                                ])
                            >ملاحظة</flux:button>
                        </div>

                        @if ($this->session)
                            <livewire:session-student-recitations
                                :key="'recitations-'.$this->session->id.'-'.$studentId"
                                :student="$attendance->student"
                                :session="$this->session"
                                :editable="$this->editable"
                            />
                        @endif
                    </div>
                @endforeach
            </div>
        @endif
    </div>

    @if ($this->teachers->isNotEmpty())
        <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <div class="border-b border-sand-200 p-4 dark:border-zinc-700">
                <flux:heading size="lg">حضور الأساتذة</flux:heading>
            </div>

            <div class="divide-y divide-sand-200 dark:divide-zinc-700">
                @foreach ($this->teachers as $teacher)
                    <div wire:key="teacher-{{ $teacher->id }}" class="flex flex-wrap items-center gap-3 p-4">
                        <div class="min-w-48 flex-1">
                            <flux:heading size="sm">{{ $teacher->display_name }}</flux:heading>
                            <flux:text size="sm" class="latin-numerals text-ink-500 dark:text-zinc-400">{{ $teacher->phone ?: '—' }}</flux:text>
                        </div>

                        <x-attendance-picker
                            :name="'teacherRows.'.$teacher->id.'.status'"
                            :selected="$this->teacherRows[$teacher->id]['status'] ?? 'present'"
                            :disabled="! $this->editable"
                            :on-select="'setTeacherStatus('.$teacher->id.', %s)'"
                            :test-id="'teacher-'.$teacher->id"
                        />

                        <flux:input
                            wire:model="teacherRows.{{ $teacher->id }}.note"
                            placeholder="ملاحظة"
                            class="max-w-40"
                            :disabled="! $this->editable"
                        />
                    </div>
                @endforeach
            </div>
        </div>
    @endif

    <flux:modal name="student-note" class="w-full max-w-lg">
        @if ($noteStudentId !== null)
            <form wire:submit="saveNote" class="space-y-6">
                <flux:heading size="lg">ملاحظة على {{ $this->attendances->firstWhere('student_id', $noteStudentId)?->student->full_name }}</flux:heading>

                <flux:textarea wire:model="rows.{{ $noteStudentId }}.note" label="نص الملاحظة" rows="3" data-test="note-text" />

                <flux:radio.group wire:model="rows.{{ $noteStudentId }}.note_polarity" label="نوع الملاحظة" variant="segmented">
                    @foreach (NotePolarity::cases() as $case)
                        <flux:radio :value="$case->value" :label="$case->label()" />
                    @endforeach
                </flux:radio.group>

                <div class="flex gap-2">
                    <flux:button type="submit" variant="primary" data-test="save-note">حفظ</flux:button>
                    <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                </div>
            </form>
        @endif
    </flux:modal>
</div>
