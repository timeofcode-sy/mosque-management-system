<?php

use App\Concerns\InteractsWithInstitute;
use App\Models\Circle;
use App\Models\CourseCircle;
use Flux\Flux;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('الحلقات')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $name = '';

    public string $level = '';

    public string $color = '#0F5132';

    public int $sort_order = 0;

    public bool $is_active = true;

    public ?int $runningCircleId = null;

    public ?int $shift_id = null;

    public string $room = '';

    public string $capacity = '';

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, Circle>
     */
    #[Computed]
    public function circles(): Collection
    {
        $courseId = $this->currentCourse?->id;

        return $this->institute->circles()
            ->with(['courseCircles' => fn ($query) => $query->where('course_id', $courseId)->with('shift', 'teachers')])
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();
    }

    /**
     * @return Collection<int, \App\Models\Shift>
     */
    #[Computed]
    public function shifts(): Collection
    {
        return $this->currentCourse?->shifts()->orderBy('sort_order')->get() ?? new Collection;
    }

    public function create(): void
    {
        $this->reset('editingId', 'name', 'level');
        $this->color = '#0F5132';
        $this->sort_order = $this->circles->count();
        $this->is_active = true;
        $this->resetValidation();

        Flux::modal('circle-form')->show();
    }

    public function edit(Circle $circle): void
    {
        $this->editingId = $circle->id;
        $this->name = $circle->name;
        $this->level = (string) $circle->level;
        $this->color = $circle->color ?: '#0F5132';
        $this->sort_order = $circle->sort_order;
        $this->is_active = $circle->is_active;
        $this->resetValidation();

        Flux::modal('circle-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'level' => ['nullable', 'string', 'max:255'],
            'color' => ['nullable', 'string', 'max:16'],
            'sort_order' => ['integer', 'min:0'],
            'is_active' => ['boolean'],
        ]);

        Circle::updateOrCreate(
            ['id' => $this->editingId],
            [...$validated, 'institute_id' => $this->institute->id],
        );

        unset($this->circles);
        Flux::modal('circle-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظت الحلقة.');
    }

    public function startRunning(Circle $circle): void
    {
        $this->runningCircleId = $circle->id;
        $this->shift_id = $this->shifts->first()?->id;
        $this->room = '';
        $this->capacity = '';
        $this->resetValidation();

        Flux::modal('run-circle')->show();
    }

    public function run(): void
    {
        $validated = $this->validate([
            'shift_id' => ['required', 'integer'],
            'room' => ['nullable', 'string', 'max:255'],
            'capacity' => ['nullable', 'integer', 'min:1', 'max:500'],
        ], attributes: ['shift_id' => 'الدوام']);

        CourseCircle::create([
            'course_id' => $this->currentCourse->id,
            'circle_id' => $this->runningCircleId,
            'shift_id' => $validated['shift_id'],
            'room' => $validated['room'] ?: null,
            'capacity' => $validated['capacity'] ?: null,
        ]);

        unset($this->circles);
        Flux::modal('run-circle')->close();
        Flux::toast(variant: 'success', text: 'شُغِّلت الحلقة في الدورة الجارية.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الحلقات" subheading="هوية الحلقة ثابتة عبر الدورات — تشغيلها ضمن دورة ودوام صفٌّ مستقل">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-circle">حلقة جديدة</flux:button>
        </x-slot>
    </x-page-header>

    @if ($this->currentCourse === null)
        <flux:callout icon="calendar-days" variant="warning">
            <flux:callout.heading>لا توجد دورة جارية</flux:callout.heading>
            <flux:callout.text>يمكنك تعريف الحلقات الآن، لكن تشغيلها يحتاج دورة جارية ودواماً.</flux:callout.text>
        </flux:callout>
    @endif

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->circles->isEmpty())
            <flux:text class="p-6 text-center">لا توجد حلقات بعد.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الحلقة</flux:table.column>
                    <flux:table.column>المستوى</flux:table.column>
                    <flux:table.column>في الدورة الجارية</flux:table.column>
                    <flux:table.column>الأستاذ</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->circles as $circle)
                        @php $running = $circle->courseCircles->first(); @endphp

                        <flux:table.row :key="$circle->id">
                            <flux:table.cell>
                                <div class="flex items-center gap-2">
                                    <span class="size-3 rounded-full" style="background-color: {{ $circle->color ?: '#0F5132' }}"></span>
                                    @if ($running)
                                        <flux:link :href="route('circles.show', $running)" wire:navigate>{{ $circle->name }}</flux:link>
                                    @else
                                        {{ $circle->name }}
                                    @endif
                                </div>
                            </flux:table.cell>
                            <flux:table.cell>{{ $circle->level ?: '—' }}</flux:table.cell>
                            <flux:table.cell>
                                @if ($running)
                                    <flux:badge color="green" size="sm">{{ $running->shift->name }}{{ $running->room ? ' · '.$running->room : '' }}</flux:badge>
                                @else
                                    <flux:text size="sm">غير مشغَّلة</flux:text>
                                @endif
                            </flux:table.cell>
                            <flux:table.cell>{{ $running?->teachers->pluck('display_name')->join('، ') ?: '—' }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="edit({{ $circle->id }})" icon="pencil">تعديل</flux:menu.item>

                                        @if ($running)
                                            <flux:menu.item :href="route('circles.show', $running)" wire:navigate icon="users">الطلاب والأساتذة</flux:menu.item>
                                        @elseif ($this->currentCourse && $this->shifts->isNotEmpty())
                                            <flux:menu.item wire:click="startRunning({{ $circle->id }})" icon="play">شغّلها في الدورة الجارية</flux:menu.item>
                                        @endif
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="circle-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل الحلقة' : 'حلقة جديدة' }}</flux:heading>

            <flux:input wire:model="name" label="اسم الحلقة" required />
            <flux:input wire:model="level" label="المستوى" placeholder="مبتدئ / متوسط / متقدّم" />

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="color" type="color" label="اللون" />
                <flux:input wire:model="sort_order" type="number" label="ترتيب العرض" min="0" />
            </div>

            <flux:switch wire:model="is_active" label="حلقة فعّالة" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-circle">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="run-circle" class="w-full max-w-lg">
        <form wire:submit="run" class="space-y-6">
            <flux:heading size="lg">تشغيل الحلقة في الدورة الجارية</flux:heading>

            <flux:select wire:model="shift_id" label="الدوام" placeholder="اختر الدوام">
                @foreach ($this->shifts as $shift)
                    <flux:select.option value="{{ $shift->id }}">{{ $shift->name }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="room" label="القاعة" />
                <flux:input wire:model="capacity" type="number" label="الطاقة الاستيعابية" min="1" />
            </div>

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="run-circle">تشغيل</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
