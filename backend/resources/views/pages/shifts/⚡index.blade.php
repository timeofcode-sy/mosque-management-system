<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\Weekday;
use App\Models\Shift;
use App\Models\ShiftDay;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('الدوامات')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $name = '';

    public string $starts_at = '16:00';

    public string $ends_at = '18:00';

    public int $sort_order = 0;

    public bool $is_active = true;

    /**
     * أيام الأسبوع المختارة — قيم weekday كسلاسل لأن checkbox يرسلها كذلك.
     *
     * @var array<int, string>
     */
    public array $weekdays = [];

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, Shift>
     */
    #[Computed]
    public function shifts(): Collection
    {
        if ($this->currentCourse === null) {
            return new Collection;
        }

        return $this->currentCourse->shifts()
            ->with('days')
            ->withCount('courseCircles')
            ->orderBy('sort_order')
            ->get();
    }

    public function create(): void
    {
        $this->reset('editingId', 'name', 'starts_at', 'ends_at', 'weekdays');
        $this->sort_order = $this->shifts->count();
        $this->is_active = true;
        $this->resetValidation();

        Flux::modal('shift-form')->show();
    }

    public function edit(Shift $shift): void
    {
        $this->editingId = $shift->id;
        $this->name = $shift->name;
        $this->starts_at = substr((string) $shift->starts_at, 0, 5);
        $this->ends_at = substr((string) $shift->ends_at, 0, 5);
        $this->sort_order = $shift->sort_order;
        $this->is_active = $shift->is_active;
        $this->weekdays = $shift->days->pluck('weekday')->map(fn (int $day) => (string) $day)->all();
        $this->resetValidation();

        Flux::modal('shift-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'starts_at' => ['required', 'date_format:H:i'],
            'ends_at' => ['required', 'date_format:H:i', 'after:starts_at'],
            'sort_order' => ['integer', 'min:0'],
            'is_active' => ['boolean'],
            'weekdays' => ['required', 'array', 'min:1'],
            'weekdays.*' => ['integer', 'between:0,6'],
        ], attributes: ['weekdays' => 'أيام الدوام']);

        DB::transaction(function () use ($validated): void {
            $shift = Shift::updateOrCreate(
                ['id' => $this->editingId],
                [...collect($validated)->except('weekdays')->all(), 'course_id' => $this->currentCourse->id],
            );

            $shift->days()->delete();

            foreach ($validated['weekdays'] as $weekday) {
                ShiftDay::create(['shift_id' => $shift->id, 'weekday' => (int) $weekday]);
            }
        });

        unset($this->shifts);
        Flux::modal('shift-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ الدوام.');
    }

    public function delete(Shift $shift): void
    {
        if ($shift->courseCircles()->exists()) {
            Flux::toast(variant: 'danger', text: 'لا يمكن حذف دوام تعمل فيه حلقات.');

            return;
        }

        $shift->delete();

        unset($this->shifts);
        Flux::toast(variant: 'success', text: 'حُذف الدوام.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الدوامات" :subheading="$this->currentCourse?->name">
        <x-slot name="actions">
            @if ($this->currentCourse)
                <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-shift">دوام جديد</flux:button>
            @endif
        </x-slot>
    </x-page-header>

    @if ($this->currentCourse === null)
        <flux:callout icon="calendar-days" variant="warning">
            <flux:callout.heading>لا توجد دورة جارية</flux:callout.heading>
            <flux:callout.text>الدوامات تُعرَّف داخل دورة — فعّل دورة أولاً.</flux:callout.text>
            <x-slot name="actions">
                <flux:button :href="route('courses.index')" wire:navigate variant="primary" size="sm">إدارة الدورات</flux:button>
            </x-slot>
        </flux:callout>
    @else
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            @forelse ($this->shifts as $shift)
                <div class="rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900" wire:key="shift-{{ $shift->id }}">
                    <div class="flex items-start justify-between gap-2">
                        <div>
                            <flux:heading size="lg">{{ $shift->name }}</flux:heading>
                            <flux:text class="latin-numerals mt-1">
                                {{ substr((string) $shift->starts_at, 0, 5) }} – {{ substr((string) $shift->ends_at, 0, 5) }}
                            </flux:text>
                        </div>

                        <flux:dropdown position="bottom" align="end">
                            <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                            <flux:menu>
                                <flux:menu.item wire:click="edit({{ $shift->id }})" icon="pencil">تعديل</flux:menu.item>
                                <flux:menu.item wire:click="delete({{ $shift->id }})" icon="trash" variant="danger">حذف</flux:menu.item>
                            </flux:menu>
                        </flux:dropdown>
                    </div>

                    <div class="mt-3 flex flex-wrap gap-1">
                        @foreach ($shift->weekdayLabels() as $label)
                            <flux:badge size="sm" color="zinc">{{ $label }}</flux:badge>
                        @endforeach
                    </div>

                    <flux:text size="sm" class="mt-3">
                        <span class="latin-numerals">{{ $shift->course_circles_count }}</span> حلقة مداومة
                    </flux:text>
                </div>
            @empty
                <flux:text class="p-6">لا توجد دوامات في هذه الدورة بعد.</flux:text>
            @endforelse
        </div>
    @endif

    <flux:modal name="shift-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل الدوام' : 'دوام جديد' }}</flux:heading>

            <flux:input wire:model="name" label="اسم الدوام" placeholder="صباحي / مسائي" required />

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="starts_at" type="time" label="يبدأ" required />
                <flux:input wire:model="ends_at" type="time" label="ينتهي" required />
            </div>

            <flux:checkbox.group wire:model="weekdays" label="أيام الدوام الأسبوعية">
                @foreach (Weekday::options() as $value => $label)
                    <flux:checkbox value="{{ $value }}" label="{{ $label }}" />
                @endforeach
            </flux:checkbox.group>

            <flux:input wire:model="sort_order" type="number" label="ترتيب العرض" min="0" />
            <flux:switch wire:model="is_active" label="دوام فعّال" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-shift">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
