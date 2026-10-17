<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\Gender;
use App\Enums\StudentStatus;
use App\Models\CourseCircle;
use App\Models\Student;
use App\Queries\StudentListQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

new #[Title('الطلاب')] class extends Component {
    use InteractsWithInstitute, WithPagination;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    #[Url(except: '')]
    public string $status = '';

    /** معرّف حلقة الدورة، أو «none» للطلاب الذين لا حلقة لهم. */
    #[Url(as: 'circle', except: '')]
    public string $courseCircleId = '';

    #[Url(except: '')]
    public string $gender = '';

    #[Url(except: '')]
    public string $grade = '';

    #[Url(as: 'from', except: '')]
    public string $bornFrom = '';

    #[Url(as: 'to', except: '')]
    public string $bornTo = '';

    /** deceased · alive */
    #[Url(except: '')]
    public string $father = '';

    #[Url(except: '')]
    public string $address = '';

    #[Url(as: 'juz', except: '')]
    public string $juzMin = '';

    /**
     * الواصفات ذات الخيارات (السكن…): معرّف الواصفة ← الخيار.
     *
     * @var array<int|string, string>
     */
    #[Url(except: [])]
    public array $fields = [];

    public bool $showFilters = false;

    public function mount(): void
    {
        $this->requireInstitute();

        // من فتح الصفحة برابطٍ فيه تصفيةٌ متقدّمة يرى لوحتها مفتوحة.
        $this->showFilters = $this->advancedCount() > 0;
    }

    public function updated(string $property): void
    {
        $this->resetPage();
    }

    private function query(): StudentListQuery
    {
        return app(StudentListQuery::class);
    }

    /**
     * @return array<string, mixed>
     */
    private function filters(): array
    {
        return [
            'status' => $this->status,
            'circle' => $this->courseCircleId,
            'gender' => $this->gender,
            'grade' => $this->grade,
            'born_from' => $this->bornFrom,
            'born_to' => $this->bornTo,
            'father' => $this->father,
            'address' => $this->address,
            'juz_min' => $this->juzMin,
            'fields' => $this->fields,
        ];
    }

    /**
     * @return array{page: \Illuminate\Pagination\LengthAwarePaginator<int, Student>, approximate: bool, total: int}
     */
    #[Computed]
    public function result(): array
    {
        return $this->query()->search($this->institute, $this->search, $this->filters(), page: $this->getPage());
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function courseCircles(): Collection
    {
        return $this->query()->filterableCircles($this->currentCourse);
    }

    /**
     * @return array{grades: list<string>, years: list<int>, fields: Collection<int, \App\Models\CustomField>}
     */
    #[Computed]
    public function options(): array
    {
        return $this->query()->filterOptions($this->institute);
    }

    /**
     * التصفيات المفعّلة بأسمائها — شاراتٌ تُزال واحدةً واحدة.
     *
     * @return list<array{key: string, label: string}>
     */
    #[Computed]
    public function chips(): array
    {
        $chips = [];
        $add = function (string $key, string $label) use (&$chips): void {
            $chips[] = ['key' => $key, 'label' => $label];
        };

        if ($this->status !== '') {
            $add('status', StudentStatus::from($this->status)->label());
        }

        if ($this->courseCircleId === StudentListQuery::NO_CIRCLE) {
            $add('courseCircleId', 'بلا حلقة');
        } elseif ($this->courseCircleId !== '') {
            $add('courseCircleId', 'حلقة '.($this->courseCircles->firstWhere('id', (int) $this->courseCircleId)?->circle->name ?? ''));
        }

        if ($this->gender !== '') {
            $add('gender', Gender::from($this->gender)->label());
        }

        if ($this->grade !== '') {
            $add('grade', 'الصف: '.$this->grade);
        }

        if ($this->bornFrom !== '' || $this->bornTo !== '') {
            $add('born', 'المواليد: '.($this->bornFrom ?: '…').' – '.($this->bornTo ?: '…'));
        }

        if ($this->father !== '') {
            $add('father', $this->father === 'deceased' ? 'الأب متوفى' : 'الأب على قيد الحياة');
        }

        if ($this->address !== '') {
            $add('address', 'العنوان: '.$this->address);
        }

        if ((int) $this->juzMin > 0) {
            $add('juzMin', "حافظ {$this->juzMin} أجزاء فأكثر");
        }

        foreach (array_filter($this->fields, fn ($value) => filled($value)) as $fieldId => $value) {
            $label = $this->options['fields']->firstWhere('id', (int) $fieldId)?->label ?? '';
            $add("fields.{$fieldId}", "{$label}: {$value}");
        }

        return $chips;
    }

    private function advancedCount(): int
    {
        return collect([$this->gender, $this->grade, $this->bornFrom, $this->bornTo, $this->father, $this->address, $this->juzMin])
            ->filter(fn ($value) => $value !== '')
            ->count() + count(array_filter($this->fields, fn ($value) => filled($value)));
    }

    public function removeFilter(string $key): void
    {
        match (true) {
            $key === 'born' => [$this->bornFrom, $this->bornTo] = ['', ''],
            str_starts_with($key, 'fields.') => $this->fields = collect($this->fields)->except(substr($key, 7))->all(),
            default => $this->{$key} = '',
        };

        $this->resetPage();
    }

    public function clearFilters(): void
    {
        $this->reset('status', 'courseCircleId', 'gender', 'grade', 'bornFrom', 'bornTo', 'father', 'address', 'juzMin', 'fields');
        $this->resetPage();
    }

    public function delete(Student $student): void
    {
        $student->delete();

        unset($this->result);
        Flux::toast(variant: 'success', text: 'حُذف الطالب — بياناته قابلة للاسترجاع.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الطلاب" :subheading="$this->institute?->name">
        <x-slot name="actions">
            <flux:button :href="route('students.create')" wire:navigate variant="primary" icon="plus" data-test="new-student">
                تسجيل طالب
            </flux:button>
        </x-slot>
    </x-page-header>

    <div class="flex flex-col gap-4">
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-[2fr_1fr_1fr_auto]">
            <flux:input
                wire:model.live.debounce.300ms="search"
                icon="magnifying-glass"
                placeholder="ابحث بالاسم أو اسم الوالد أو رقم المعرف أو الهاتف"
                clearable
                data-test="student-search"
            />

            <flux:select wire:model.live="status" placeholder="كل الحالات">
                <flux:select.option value="">كل الحالات</flux:select.option>
                @foreach (StudentStatus::options() as $value => $label)
                    <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:select wire:model.live="courseCircleId" placeholder="كل الحلقات">
                <flux:select.option value="">كل الحلقات</flux:select.option>
                <flux:select.option value="{{ StudentListQuery::NO_CIRCLE }}">بلا حلقة</flux:select.option>
                @foreach ($this->courseCircles as $courseCircle)
                    <flux:select.option value="{{ $courseCircle->id }}">{{ $courseCircle->circle->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:button
                wire:click="$toggle('showFilters')"
                icon="adjustments-horizontal"
                :variant="$showFilters ? 'filled' : 'outline'"
                data-test="toggle-filters"
            >
                تصفية متقدّمة
            </flux:button>
        </div>

        @if ($showFilters)
            <div class="grid gap-4 rounded-xl border border-line bg-raised p-4 sm:grid-cols-2 lg:grid-cols-4" data-test="advanced-filters">
                <flux:select wire:model.live="father" label="الأب">
                    <flux:select.option value="">الكل</flux:select.option>
                    <flux:select.option value="deceased">متوفى</flux:select.option>
                    <flux:select.option value="alive">على قيد الحياة</flux:select.option>
                </flux:select>

                @foreach ($this->options['fields'] as $field)
                    <flux:select wire:model.live="fields.{{ $field->id }}" :label="$field->label" wire:key="field-{{ $field->id }}">
                        <flux:select.option value="">الكل</flux:select.option>
                        @foreach ($field->options ?? [] as $option)
                            <flux:select.option value="{{ $option }}">{{ $option }}</flux:select.option>
                        @endforeach
                    </flux:select>
                @endforeach

                <flux:input wire:model.live.debounce.400ms="address" label="العنوان يحوي" placeholder="مثلاً: زملكا، العسقلاني" icon="map-pin" />

                <flux:select wire:model.live="grade" label="الصف">
                    <flux:select.option value="">كل الصفوف</flux:select.option>
                    @foreach ($this->options['grades'] as $grade)
                        <flux:select.option value="{{ $grade }}">{{ $grade }}</flux:select.option>
                    @endforeach
                </flux:select>

                <flux:select wire:model.live="gender" label="الجنس">
                    <flux:select.option value="">الكل</flux:select.option>
                    @foreach (Gender::options() as $value => $label)
                        <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                    @endforeach
                </flux:select>

                <div class="grid grid-cols-2 gap-2">
                    <flux:select wire:model.live="bornFrom" label="مواليد من">
                        <flux:select.option value="">—</flux:select.option>
                        @foreach ($this->options['years'] as $year)
                            <flux:select.option value="{{ $year }}">{{ $year }}</flux:select.option>
                        @endforeach
                    </flux:select>
                    <flux:select wire:model.live="bornTo" label="إلى">
                        <flux:select.option value="">—</flux:select.option>
                        @foreach ($this->options['years'] as $year)
                            <flux:select.option value="{{ $year }}">{{ $year }}</flux:select.option>
                        @endforeach
                    </flux:select>
                </div>

                {{-- نصٌّ بلوحة أرقام لا type="number": المتصفّح العربي يعرض الرقم فيه بالأرقام الهندية، والنظام لاتينيّ الأرقام. --}}
                <flux:input wire:model.live.debounce.400ms="juzMin" inputmode="numeric" pattern="[0-9]*" maxlength="2" class="latin-numerals" label="الأجزاء المحفوظة (على الأقل)" />
            </div>
        @endif

        @if ($this->chips !== [])
            <div class="flex flex-wrap items-center gap-2" data-test="active-filters">
                @foreach ($this->chips as $chip)
                    <flux:badge wire:key="chip-{{ $chip['key'] }}" color="zinc" size="sm">
                        {{ $chip['label'] }}
                        <flux:badge.close wire:click="removeFilter('{{ $chip['key'] }}')" />
                    </flux:badge>
                @endforeach
                <flux:button wire:click="clearFilters" size="xs" variant="ghost" icon="x-mark">مسح التصفية</flux:button>
            </div>
        @endif
    </div>

    <div class="flex flex-wrap items-center justify-between gap-2">
        <flux:text size="sm" class="latin-numerals text-muted" data-test="result-count">
            {{ $this->result['total'] }} طالباً
        </flux:text>

        @if ($this->result['approximate'])
            <flux:text size="sm" class="text-warning" data-test="approximate">
                لا تطابقَ تامّاً لـ«{{ $search }}» — هذه أقرب النتائج.
            </flux:text>
        @endif
    </div>

    <div class="rounded-xl border border-line bg-raised">
        @if ($this->result['page']->isEmpty())
            <flux:text class="p-6 text-center">لا توجد نتائج مطابقة.</flux:text>
        @else
            <flux:table :paginate="$this->result['page']">
                <flux:table.columns>
                    <flux:table.column>الطالب</flux:table.column>
                    <flux:table.column>رقم المعرف</flux:table.column>
                    <flux:table.column>الحلقة الحالية</flux:table.column>
                    <flux:table.column>الهاتف</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->result['page'] as $student)
                        @php $enrollment = $student->enrollments->first(); @endphp

                        <flux:table.row :key="$student->id">
                            <flux:table.cell>
                                <flux:link :href="route('students.show', $student)" wire:navigate>{{ $student->full_name }}</flux:link>
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $student->registration_no ?: '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $enrollment?->courseCircle->circle->name ?? 'بلا حلقة' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $student->phone ?: '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $student->status->label() }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item :href="route('students.show', $student)" wire:navigate icon="identification">الملف</flux:menu.item>
                                        <flux:menu.item :href="route('students.edit', $student)" wire:navigate icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete('{{ $student->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>
</div>
