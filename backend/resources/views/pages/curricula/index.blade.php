<?php

use App\Actions\SaveCurriculumItem;
use App\Concerns\InteractsWithInstitute;
use App\Enums\CurriculumType;
use App\Models\Curriculum;
use App\Queries\InstituteCatalogQuery;
use App\Models\CurriculumItem;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('المناهج')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $name = '';

    public string $type = 'custom';

    public string $description = '';

    public int $sort_order = 0;

    public bool $is_active = true;

    public ?int $itemCurriculumId = null;

    public ?int $editingItemId = null;

    public string $itemName = '';

    public string $itemCode = '';

    public int $itemSortOrder = 0;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * المناهج العامة (المزروعة) ومناهج هذا المعهد معاً.
     *
     * @return Collection<int, Curriculum>
     */
    #[Computed]
    public function curricula(): Collection
    {
        return app(InstituteCatalogQuery::class)->curricula($this->institute);
    }

    public function create(): void
    {
        $this->reset('editingId', 'name', 'description');
        $this->type = CurriculumType::Custom->value;
        $this->sort_order = $this->curricula->count();
        $this->is_active = true;
        $this->resetValidation();

        Flux::modal('curriculum-form')->show();
    }

    public function edit(Curriculum $curriculum): void
    {
        $this->editingId = $curriculum->id;
        $this->name = $curriculum->name;
        $this->type = $curriculum->type->value;
        $this->description = (string) $curriculum->description;
        $this->sort_order = $curriculum->sort_order;
        $this->is_active = $curriculum->is_active;
        $this->resetValidation();

        Flux::modal('curriculum-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'type' => ['required', Rule::enum(CurriculumType::class)],
            'description' => ['nullable', 'string'],
            'sort_order' => ['integer', 'min:0'],
            'is_active' => ['boolean'],
        ], attributes: ['name' => 'اسم المنهج']);

        Curriculum::updateOrCreate(
            ['id' => $this->editingId],
            [
                ...$validated,
                'institute_id' => $this->institute->id,
                'slug' => Str::slug($validated['name']) ?: Str::random(8),
            ],
        );

        unset($this->curricula);
        Flux::modal('curriculum-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ المنهج.');
    }

    public function createItem(Curriculum $curriculum): void
    {
        $this->itemCurriculumId = $curriculum->id;
        $this->reset('editingItemId', 'itemName', 'itemCode');
        $this->itemSortOrder = $curriculum->items()->count();
        $this->resetValidation();

        Flux::modal('item-form')->show();
    }

    public function editItem(CurriculumItem $item): void
    {
        $this->itemCurriculumId = $item->curriculum_id;
        $this->editingItemId = $item->id;
        $this->itemName = $item->name;
        $this->itemCode = (string) $item->code;
        $this->itemSortOrder = $item->sort_order;
        $this->resetValidation();

        Flux::modal('item-form')->show();
    }

    public function saveItem(): void
    {
        $validated = $this->validate([
            'itemName' => ['required', 'string', 'max:255'],
            'itemCode' => [
                'nullable', 'string', 'max:64',
                Rule::unique('curriculum_items', 'code')
                    ->where('curriculum_id', $this->itemCurriculumId)
                    ->ignore($this->editingItemId),
            ],
            'itemSortOrder' => ['integer', 'min:0'],
        ], attributes: ['itemName' => 'اسم البند', 'itemCode' => 'الرمز']);

        app(SaveCurriculumItem::class)->handle(
            Curriculum::findOrFail($this->itemCurriculumId),
            [
                'name' => $validated['itemName'],
                'code' => $validated['itemCode'],
                'sort_order' => $validated['itemSortOrder'],
            ],
            $this->editingItemId,
        );

        unset($this->curricula);
        Flux::modal('item-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ البند.');
    }

    public function deleteItem(CurriculumItem $item): void
    {
        if ($item->progress()->exists()) {
            Flux::toast(variant: 'danger', text: 'لا يمكن حذف بند مرتبط بسجل محفوظات.');

            return;
        }

        $item->delete();

        unset($this->curricula);
        Flux::toast(variant: 'success', text: 'حُذف البند.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="المناهج" subheading="القرآن والحديث والمتون — والمناهج التي يضيفها المعهد">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-curriculum">منهج جديد</flux:button>
        </x-slot>
    </x-page-header>

    <div class="flex flex-col gap-4">
        @foreach ($this->curricula as $curriculum)
            <div wire:key="curriculum-{{ $curriculum->id }}" class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
                <div class="flex flex-wrap items-center justify-between gap-2 border-b border-sand-200 p-4 dark:border-zinc-700">
                    <div>
                        <div class="flex items-center gap-2">
                            <flux:heading size="lg">{{ $curriculum->name }}</flux:heading>
                            <flux:badge size="sm" color="zinc">{{ $curriculum->type->label() }}</flux:badge>
                            @if ($curriculum->institute_id === null)
                                <flux:badge size="sm" color="amber">عام</flux:badge>
                            @endif
                        </div>
                        <flux:text size="sm" class="mt-1">
                            <span class="latin-numerals">{{ $curriculum->items_count }}</span> بنداً
                        </flux:text>
                    </div>

                    <div class="flex gap-2">
                        <flux:button wire:click="createItem('{{ $curriculum->uuid }}')" size="sm" icon="plus">بند</flux:button>
                        <flux:button wire:click="edit('{{ $curriculum->uuid }}')" size="sm" variant="subtle" icon="pencil">تعديل</flux:button>
                    </div>
                </div>

                <div class="flex flex-wrap gap-2 p-4">
                    @forelse ($curriculum->items as $item)
                        <flux:badge wire:key="item-{{ $item->id }}" color="zinc">
                            <button type="button" wire:click="editItem('{{ $item->uuid }}')" class="cursor-pointer">{{ $item->name }}</button>
                            <flux:badge.close wire:click="deleteItem('{{ $item->uuid }}')" />
                        </flux:badge>
                    @empty
                        <flux:text>لا توجد بنود في هذا المنهج.</flux:text>
                    @endforelse
                </div>
            </div>
        @endforeach
    </div>

    <flux:modal name="curriculum-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل المنهج' : 'منهج جديد' }}</flux:heading>

            <flux:input wire:model="name" label="اسم المنهج" required />

            <flux:select wire:model="type" label="النوع">
                @foreach (CurriculumType::options() as $value => $label)
                    <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                @endforeach
            </flux:select>

            <flux:textarea wire:model="description" label="الوصف" rows="2" />
            <flux:input wire:model="sort_order" type="number" label="ترتيب العرض" min="0" />
            <flux:switch wire:model="is_active" label="منهج فعّال" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-curriculum">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="item-form" class="w-full max-w-lg">
        <form wire:submit="saveItem" class="space-y-6">
            <flux:heading size="lg">{{ $editingItemId ? 'تعديل البند' : 'بند جديد' }}</flux:heading>

            <flux:input wire:model="itemName" label="اسم البند" required />
            <flux:input wire:model="itemCode" label="الرمز" />
            <flux:input wire:model="itemSortOrder" type="number" label="ترتيب العرض" min="0" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-curriculum-item">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
