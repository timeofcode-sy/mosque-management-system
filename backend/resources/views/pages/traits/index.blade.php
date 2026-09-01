<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\TraitPolarity;
use App\Models\PersonalTrait;
use App\Queries\InstituteCatalogQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('الصفات')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $name = '';

    public string $polarity = 'positive';

    public string $color = '#0F5132';

    public int $sort_order = 0;

    public bool $is_active = true;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * الصفات العامة المزروعة وصفات هذا المعهد معاً.
     *
     * @return Collection<int, PersonalTrait>
     */
    #[Computed]
    public function personalTraits(): Collection
    {
        return app(InstituteCatalogQuery::class)->personalTraits($this->institute);
    }

    public function create(): void
    {
        $this->reset('editingId', 'name');
        $this->polarity = TraitPolarity::Positive->value;
        $this->color = '#0F5132';
        $this->sort_order = $this->personalTraits->count();
        $this->is_active = true;
        $this->resetValidation();

        Flux::modal('trait-form')->show();
    }

    public function edit(PersonalTrait $personalTrait): void
    {
        $this->editingId = $personalTrait->id;
        $this->name = $personalTrait->name;
        $this->polarity = $personalTrait->polarity->value;
        $this->color = $personalTrait->color ?: '#0F5132';
        $this->sort_order = $personalTrait->sort_order;
        $this->is_active = $personalTrait->is_active;
        $this->resetValidation();

        Flux::modal('trait-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'polarity' => ['required', Rule::enum(TraitPolarity::class)],
            'color' => ['nullable', 'string', 'max:16'],
            'sort_order' => ['integer', 'min:0'],
            'is_active' => ['boolean'],
        ], attributes: ['name' => 'اسم الصفة']);

        PersonalTrait::updateOrCreate(
            ['id' => $this->editingId],
            [
                ...$validated,
                'institute_id' => $this->institute->id,
                'slug' => Str::slug($validated['name']) ?: Str::random(8),
            ],
        );

        unset($this->personalTraits);
        Flux::modal('trait-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظت الصفة.');
    }

    public function delete(PersonalTrait $personalTrait): void
    {
        if ($personalTrait->students()->exists()) {
            Flux::toast(variant: 'danger', text: 'لا يمكن حذف صفة مسنَدة إلى طلاب.');

            return;
        }

        $personalTrait->delete();

        unset($this->personalTraits);
        Flux::toast(variant: 'success', text: 'حُذفت الصفة.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الصفات الشخصية والسلوكية" subheading="الصفات المزروعة عامة لكل المعاهد — وما تضيفه هنا خاصٌّ بمعهدك">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-trait">صفة جديدة</flux:button>
        </x-slot>
    </x-page-header>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        <flux:table>
            <flux:table.columns>
                <flux:table.column>الصفة</flux:table.column>
                <flux:table.column>الاتجاه</flux:table.column>
                <flux:table.column>النطاق</flux:table.column>
                <flux:table.column>الطلاب</flux:table.column>
                <flux:table.column></flux:table.column>
            </flux:table.columns>

            <flux:table.rows>
                @foreach ($this->personalTraits as $personalTrait)
                    <flux:table.row :key="$personalTrait->id">
                        <flux:table.cell>
                            <div class="flex items-center gap-2">
                                <span class="size-3 rounded-full" style="background-color: {{ $personalTrait->color ?: '#0F5132' }}"></span>
                                {{ $personalTrait->name }}
                            </div>
                        </flux:table.cell>
                        <flux:table.cell>{{ $personalTrait->polarity->label() }}</flux:table.cell>
                        <flux:table.cell>
                            @if ($personalTrait->institute_id === null)
                                <flux:badge size="sm" color="amber">عامة</flux:badge>
                            @else
                                <flux:badge size="sm" color="zinc">خاصّة بالمعهد</flux:badge>
                            @endif
                        </flux:table.cell>
                        <flux:table.cell class="latin-numerals">{{ $personalTrait->students_count }}</flux:table.cell>
                        <flux:table.cell>
                            @if ($personalTrait->institute_id !== null)
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="edit('{{ $personalTrait->uuid }}')" icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete('{{ $personalTrait->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            @endif
                        </flux:table.cell>
                    </flux:table.row>
                @endforeach
            </flux:table.rows>
        </flux:table>
    </div>

    <flux:modal name="trait-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل الصفة' : 'صفة جديدة' }}</flux:heading>

            <flux:input wire:model="name" label="اسم الصفة" required />

            <flux:select wire:model="polarity" label="الاتجاه">
                @foreach (TraitPolarity::options() as $value => $label)
                    <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="color" type="color" label="اللون" />
                <flux:input wire:model="sort_order" type="number" label="ترتيب العرض" min="0" />
            </div>

            <flux:switch wire:model="is_active" label="صفة فعّالة" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-trait">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
