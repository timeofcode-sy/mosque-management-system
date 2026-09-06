<?php

use App\Actions\AwardStudentPoints;
use App\Actions\BuildStudentCoverageMap;
use App\Actions\DeleteRecitation;
use App\Actions\SaveRecitation;
use App\Enums\PointReason;
use App\Enums\RecitationGrade;
use App\Models\AttendanceSession;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Support\PointsSettings;
use App\Support\Quran;
use Flux\Flux;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Reactive;
use Livewire\Component;

/**
 * تسميعات الطالب ونقاطه التقديرية داخل جلسة واحدة.
 *
 * مكوّن متداخل لا جزءٌ من صفحة الجلسة: حالة نموذج التسميع (الجزء، السورة، المدى،
 * التقدير) حالةٌ لكل طالب على حدة، ولو عاشت في الصفحة الأم لتضاعفت بعدد الطلاب.
 * أما التفقّد ونسبته فيبقيان في الأم، فهما رقم واحد للحلقة كلها.
 */
new class extends Component
{
    public Student $student;

    public AttendanceSession $session;

    #[Reactive]
    public bool $editable = true;

    public ?int $juz = null;

    public ?int $surah = null;

    public ?int $fromAyah = null;

    public ?int $toAyah = null;

    public string $grade = '';

    public string $pointReason = '';

    public string $pointValue = '';

    public string $pointNote = '';

    /** التسميع المفتوح للتصحيح — فارغٌ يعني تسميعاً جديداً. */
    public ?int $editingRecitationId = null;

    /** المنحة المفتوحة للتصحيح — فارغةٌ تعني منحة جديدة. */
    public ?int $editingAwardId = null;

    /**
     * @return Collection<int, MemorizationLog>
     */
    #[Computed]
    public function recitations(): Collection
    {
        return MemorizationLog::query()
            ->where('student_id', $this->student->id)
            ->where('attendance_session_id', $this->session->id)
            ->orderBy('id')
            ->get();
    }

    /**
     * @return Collection<int, StudentPoint>
     */
    #[Computed]
    public function awards(): Collection
    {
        return StudentPoint::query()
            ->where('student_id', $this->student->id)
            ->where('attendance_session_id', $this->session->id)
            ->orderBy('id')
            ->get();
    }

    /**
     * ما سمّعه الطالب سابقاً — منه يُقترح المقطع غير المكتمل، وبه تُطرح الآيات المكرّرة.
     *
     * السجلّ قيد التصحيح يُستثنى منها، وإلا حُسب مكرّراً لنفسه فصارت نقاطه صفراً.
     *
     * @return array<int, array<int, array{int, int}>>
     */
    #[Computed]
    public function coverage(): array
    {
        return app(BuildStudentCoverageMap::class)->handle($this->student, $this->editingRecitationId);
    }

    /**
     * @return array<int, int>
     */
    #[Computed]
    public function surahsOfJuz(): array
    {
        return Quran::surahsOfJuz($this->juz ?? 30);
    }

    /**
     * الأسطر والنقاط المتوقّعة قبل الحفظ — يراها الأستاذ وهو يختار المدى والتقدير.
     *
     * @return array{lines: float, new_lines: float, points: float}
     */
    #[Computed]
    public function preview(): array
    {
        if (! $this->hasValidRange()) {
            return ['lines' => 0.0, 'new_lines' => 0.0, 'points' => 0.0];
        }

        $lines = Quran::linesForRange($this->surah, $this->fromAyah, $this->surah, $this->toAyah);

        $newLines = 0.0;

        foreach (BuildStudentCoverageMap::newAyahsIn($this->coverage, $this->surah, $this->fromAyah, $this->surah, $this->toAyah) as $surah => $ayahs) {
            $newLines += Quran::linesOfAyahs($surah, $ayahs);
        }

        $settings = PointsSettings::for($this->session->courseCircle->circle->institute);

        return [
            'lines' => $lines,
            'new_lines' => round($newLines, 2),
            'points' => $settings->quranPoints(round($newLines, 2), RecitationGrade::tryFrom($this->grade)),
        ];
    }

    public function openRecitation(): void
    {
        $this->editingRecitationId = null;
        unset($this->coverage);

        $this->juz = $this->lastJuz();
        $this->grade = RecitationGrade::Excellent->value;
        $this->resetValidation();

        $this->selectFirstSurahOfJuz();

        Flux::modal($this->recitationModal())->show();
    }

    /**
     * فتح تسميع مسجَّل على نموذجه لتصحيحه — النموذج يعرف سورةً واحدة، فالمدى العابر
     * لعدّة سور (لا يأتي إلا من المزامنة) يبقى على حذفه وإعادة تسجيله.
     */
    public function editRecitation(MemorizationLog $log): void
    {
        if (! $this->editable || ! $this->owns($log) || $log->from_surah !== $log->to_surah) {
            return;
        }

        $this->editingRecitationId = $log->id;
        unset($this->coverage);

        $surah = (int) $log->from_surah;

        $this->surah = $surah;
        $this->juz = in_array($surah, Quran::surahsOfJuz((int) $log->juz), true)
            ? (int) $log->juz
            : Quran::juzOfSurah($surah);
        $this->fromAyah = $log->from_ayah;
        $this->toAyah = $log->to_ayah;
        $this->grade = $log->grade?->value ?? RecitationGrade::Excellent->value;
        $this->resetValidation();

        Flux::modal($this->recitationModal())->show();
    }

    public function updatedJuz(): void
    {
        unset($this->surahsOfJuz);

        $this->selectFirstSurahOfJuz();
    }

    public function updatedSurah(): void
    {
        $this->suggestRange();
    }

    public function saveRecitation(): void
    {
        if (! $this->editable) {
            return;
        }

        $this->validate([
            'juz' => ['required', 'integer', 'between:1,30'],
            'surah' => ['required', 'integer', 'between:1,114'],
            'fromAyah' => ['required', 'integer', 'min:1'],
            'toAyah' => ['required', 'integer', 'min:1', 'gte:fromAyah'],
            'grade' => ['required', Illuminate\Validation\Rule::enum(RecitationGrade::class)],
        ], attributes: [
            'surah' => 'السورة', 'fromAyah' => 'من آية', 'toAyah' => 'إلى آية', 'grade' => 'التقدير',
        ]);

        try {
            app(SaveRecitation::class)->handle(
                $this->session,
                $this->student,
                [
                    'from_surah' => $this->surah,
                    'from_ayah' => $this->fromAyah,
                    'to_surah' => $this->surah,
                    'to_ayah' => $this->toAyah,
                    'grade' => $this->grade,
                    'juz' => $this->juz,
                ],
                auth()->user(),
                editingId: $this->editingRecitationId,
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        $edited = $this->editingRecitationId !== null;

        $this->editingRecitationId = null;

        unset($this->recitations, $this->coverage);
        Flux::modal($this->recitationModal())->close();
        Flux::toast(variant: 'success', text: $edited ? 'عُدّل التسميع.' : 'سُجّل التسميع.');
    }

    public function deleteRecitation(MemorizationLog $log): void
    {
        if (! $this->editable || ! $this->owns($log)) {
            return;
        }

        try {
            app(DeleteRecitation::class)->handle($log);
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->recitations, $this->coverage);
        Flux::toast(variant: 'success', text: 'حُذف التسميع.');
    }

    public function openPoints(): void
    {
        $this->editingAwardId = null;
        $this->pointReason = PointReason::Participation->value;
        $this->pointValue = '';
        $this->pointNote = '';
        $this->resetValidation();

        Flux::modal($this->pointsModal())->show();
    }

    /**
     * فتح منحة مسجَّلة على نموذجها لتصحيح قيمتها أو سببها.
     */
    public function editAward(StudentPoint $studentPoint): void
    {
        if (! $this->editable || ! $this->owns($studentPoint)) {
            return;
        }

        $this->editingAwardId = $studentPoint->id;
        $this->pointReason = $studentPoint->reason->value;
        $this->pointValue = (string) (float) $studentPoint->points;
        $this->pointNote = (string) $studentPoint->note;
        $this->resetValidation();

        Flux::modal($this->pointsModal())->show();
    }

    public function savePoints(): void
    {
        if (! $this->editable) {
            return;
        }

        $this->validate([
            'pointReason' => ['required', Illuminate\Validation\Rule::enum(PointReason::class)],
            'pointValue' => ['required', 'numeric', 'not_in:0', 'between:-100,100'],
            'pointNote' => ['nullable', 'string', 'max:500'],
        ], attributes: ['pointReason' => 'السبب', 'pointValue' => 'النقاط', 'pointNote' => 'الملاحظة']);

        try {
            app(AwardStudentPoints::class)->handle(
                $this->student,
                ['points' => $this->pointValue, 'reason' => $this->pointReason, 'note' => $this->pointNote],
                auth()->user(),
                $this->session,
                editingId: $this->editingAwardId,
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        $edited = $this->editingAwardId !== null;

        $this->editingAwardId = null;

        unset($this->awards);
        Flux::modal($this->pointsModal())->close();
        Flux::toast(variant: 'success', text: $edited ? 'عُدّلت النقاط.' : 'مُنحت النقاط.');
    }

    public function deleteAward(StudentPoint $studentPoint): void
    {
        if (! $this->editable || ! $this->owns($studentPoint)) {
            return;
        }

        $studentPoint->delete();

        unset($this->awards);
        Flux::toast(variant: 'success', text: 'حُذفت النقاط.');
    }

    public function recitationModal(): string
    {
        return "recitation-{$this->student->id}";
    }

    public function pointsModal(): string
    {
        return "points-{$this->student->id}";
    }

    /**
     * السجلّ لهذا الطالب في هذه الجلسة — المعرّف يأتي من المتصفّح فلا يُؤتمن وحده.
     */
    private function owns(MemorizationLog|StudentPoint $record): bool
    {
        return $record->student_id === $this->student->id
            && $record->attendance_session_id === $this->session->id;
    }

    /**
     * جزء آخر تسميع للطالب، أو الثلاثون إن لم يسبق له تسميع.
     */
    private function lastJuz(): int
    {
        return (int) (MemorizationLog::query()
            ->where('student_id', $this->student->id)
            ->whereNotNull('juz')
            ->latest('id')
            ->value('juz') ?? 30);
    }

    private function selectFirstSurahOfJuz(): void
    {
        $this->surah = Quran::surahsOfJuz($this->juz ?? 30)[0] ?? 1;

        $this->suggestRange();
    }

    /**
     * الافتراض: أوّل مقطع غير مغطّى في السورة — الملك 1–12 مسجّلة ⇒ يُقترح 13–30.
     */
    private function suggestRange(): void
    {
        [$from, $to] = BuildStudentCoverageMap::firstGapIn($this->coverage, (int) $this->surah);

        $this->fromAyah = $from;
        $this->toAyah = $to;
    }

    private function hasValidRange(): bool
    {
        return $this->surah !== null
            && $this->fromAyah !== null
            && $this->toAyah !== null
            && $this->fromAyah >= 1
            && $this->toAyah >= $this->fromAyah
            && $this->toAyah <= Quran::ayahs($this->surah);
    }
}; ?>

<div class="flex w-full flex-wrap items-center gap-2">
    <flux:button
        size="sm"
        variant="subtle"
        icon="book-open"
        :disabled="! $editable"
        wire:click="openRecitation"
        :data-test="'open-recitation-'.$student->id"
    >تسميع</flux:button>

    <flux:button
        size="sm"
        variant="subtle"
        icon="star"
        :disabled="! $editable"
        wire:click="openPoints"
        :data-test="'open-points-'.$student->id"
    >نقاط</flux:button>

    {{-- القلم يفتح المسجَّل على نموذجه، فالخطأ في التقدير أو المدى يُصحَّح ولا يُمحى ويُعاد --}}
    @foreach ($this->recitations as $log)
        <flux:badge wire:key="recitation-{{ $log->id }}" size="sm" :color="$log->grade?->color() ?? 'zinc'" class="latin-numerals">
            {{ Quran::name($log->from_surah) }} {{ $log->from_ayah }}–{{ $log->to_ayah }}
            @if ($log->grade) · {{ $log->grade->label() }} @endif
            · {{ rtrim(rtrim(number_format((float) $log->points, 2, '.', ''), '0'), '.') }} نقطة
            @if ($editable)
                {{-- المدى العابر لعدّة سور لا يسعه النموذج، فيبقى على الحذف وحده --}}
                @if ($log->from_surah === $log->to_surah)
                    <x-badge-edit
                        wire:click="editRecitation('{{ $log->uuid }}')"
                        :data-test="'edit-recitation-'.$log->id"
                    />
                @endif
                <flux:badge.close wire:click="deleteRecitation('{{ $log->uuid }}')" />
            @endif
        </flux:badge>
    @endforeach

    @foreach ($this->awards as $award)
        <flux:badge wire:key="award-{{ $award->id }}" size="sm" :color="$award->points < 0 ? 'red' : 'green'" class="latin-numerals">
            {{ $award->points > 0 ? '+' : '' }}{{ rtrim(rtrim(number_format((float) $award->points, 2, '.', ''), '0'), '.') }}
            {{ $award->reason->label() }}
            @if ($editable)
                <x-badge-edit
                    wire:click="editAward('{{ $award->uuid }}')"
                    :data-test="'edit-award-'.$award->id"
                />
                <flux:badge.close wire:click="deleteAward('{{ $award->uuid }}')" />
            @endif
        </flux:badge>
    @endforeach

    <flux:modal :name="$this->recitationModal()" class="w-full max-w-lg">
        <form wire:submit="saveRecitation" class="space-y-6">
            <flux:heading size="lg">{{ $editingRecitationId ? 'تعديل تسميع' : 'تسميع' }} {{ $student->full_name }}</flux:heading>

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:select wire:model.live="juz" label="الجزء" class="latin-numerals" :data-test="'recitation-juz-'.$student->id">
                    @for ($number = 1; $number <= 30; $number++)
                        <flux:select.option :value="$number">{{ $number }}</flux:select.option>
                    @endfor
                </flux:select>

                <flux:select wire:model.live="surah" label="السورة" :data-test="'recitation-surah-'.$student->id">
                    @foreach ($this->surahsOfJuz as $number)
                        <flux:select.option :value="$number">{{ $number }} · {{ Quran::name($number) }}</flux:select.option>
                    @endforeach
                </flux:select>
            </div>

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input
                    wire:model.live="fromAyah"
                    type="number" min="1" :max="Quran::ayahs((int) $surah)"
                    label="من آية"
                    class="latin-numerals"
                    :data-test="'recitation-from-'.$student->id"
                />
                <flux:input
                    wire:model.live="toAyah"
                    type="number" min="1" :max="Quran::ayahs((int) $surah)"
                    label="إلى آية"
                    class="latin-numerals"
                    :data-test="'recitation-to-'.$student->id"
                />
            </div>

            <flux:field>
                <flux:label>التقدير</flux:label>

                <div class="inline-flex rounded-lg shadow-xs" role="radiogroup">
                    @foreach (RecitationGrade::cases() as $case)
                        <button
                            type="button"
                            role="radio"
                            aria-checked="{{ $grade === $case->value ? 'true' : 'false' }}"
                            wire:click="$set('grade', '{{ $case->value }}')"
                            data-test="recitation-grade-{{ $student->id }}-{{ $case->value }}"
                            @class([
                                'border px-3 py-1.5 text-sm font-medium transition first:rounded-s-lg last:rounded-e-lg -me-px last:me-0',
                                'bg-brand-600 text-white border-brand-600' => $grade === $case->value,
                                'border-sand-300 text-ink-700 hover:bg-brand-50 dark:border-zinc-600 dark:text-zinc-200 dark:hover:bg-zinc-800' => $grade !== $case->value,
                            ])
                        >{{ $case->label() }}</button>
                    @endforeach
                </div>
            </flux:field>

            <div class="latin-numerals rounded-lg border border-sand-200 bg-sand-50 p-3 text-sm dark:border-zinc-700 dark:bg-zinc-800">
                <span class="text-ink-500 dark:text-zinc-400">الأسطر</span>
                {{ $this->preview['lines'] }}
                <span class="mx-2 text-ink-500 dark:text-zinc-400">·</span>
                <span class="text-ink-500 dark:text-zinc-400">الجديد</span>
                {{ $this->preview['new_lines'] }}
                <span class="mx-2 text-ink-500 dark:text-zinc-400">·</span>
                <span class="text-ink-500 dark:text-zinc-400">النقاط</span>
                <span class="font-semibold text-brand-600 dark:text-brand-300" data-test="recitation-points-{{ $student->id }}">{{ $this->preview['points'] }}</span>
            </div>

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" :data-test="'save-recitation-'.$student->id">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal :name="$this->pointsModal()" class="w-full max-w-lg">
        <form wire:submit="savePoints" class="space-y-6">
            <flux:heading size="lg">{{ $editingAwardId ? 'تعديل النقاط' : 'نقاط تقديرية' }} · {{ $student->full_name }}</flux:heading>

            <flux:select wire:model="pointReason" label="السبب" :data-test="'point-reason-'.$student->id">
                @foreach (PointReason::options() as $value => $label)
                    <flux:select.option :value="$value">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:input
                wire:model="pointValue"
                type="number" step="0.5" min="-100" max="100"
                label="النقاط"
                description="تقبل السالب — الخصم على المشاغبة"
                class="latin-numerals"
                :data-test="'point-value-'.$student->id"
            />

            <flux:textarea wire:model="pointNote" label="ملاحظة" rows="2" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" :data-test="'save-points-'.$student->id">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
