<?php

use App\Actions\SaveCurriculum;
use App\Actions\SaveCurriculumItem;
use App\Concerns\InteractsWithInstitute;
use App\Enums\CurriculumType;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Queries\InstituteCatalogQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('المناهج')] class extends Component
{
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

    /** عدّاد البند: عدد الأحاديث لبنود الحديث، وعدد الأبيات لبنود المتون. */
    public ?int $itemCount = null;

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

    /**
     * المنهج الأب للبند المفتوح في المودال — منه يُعرف نوع العدّاد ويُحرَس القرآن.
     */
    #[Computed]
    public function itemCurriculum(): ?Curriculum
    {
        return $this->itemCurriculumId === null
            ? null
            : $this->curricula->firstWhere('id', $this->itemCurriculumId);
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

        // ✅ م.6.5 — الفعلُ المشترك بدل الكتابة المباشرة، فلا يفترق كاتبا المنهج
        // بين اللوحة والديسكتوب. وفيه حراسةُ «العامُّ لا يُحرَّر من معهد».
        $editing = $this->editingId === null
            ? null
            : $this->curricula->firstWhere('id', $this->editingId);

        try {
            app(SaveCurriculum::class)->handle($this->institute, $validated, $editing);
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->curricula);
        Flux::modal('curriculum-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ المنهج.');
    }

    public function createItem(Curriculum $curriculum): void
    {
        if ($this->rejectFixedQuran($curriculum)) {
            return;
        }

        $this->itemCurriculumId = $curriculum->id;
        $this->reset('editingItemId', 'itemName', 'itemCode', 'itemCount');
        $this->itemSortOrder = $curriculum->items()->count();
        $this->resetValidation();
        unset($this->itemCurriculum);

        Flux::modal('item-form')->show();
    }

    public function editItem(CurriculumItem $item): void
    {
        $this->itemCurriculumId = $item->curriculum_id;
        $this->editingItemId = $item->id;
        $this->itemName = $item->name;
        $this->itemCode = (string) $item->code;
        $this->itemSortOrder = $item->sort_order;
        $this->itemCount = $this->countOf($item);
        $this->resetValidation();
        unset($this->itemCurriculum);

        Flux::modal('item-form')->show();
    }

    public function saveItem(): void
    {
        $curriculum = Curriculum::findOrFail($this->itemCurriculumId);

        // بندٌ جديد في القرآن مرفوض؛ وتعديل اسم جزء قائم مسموح.
        if ($this->editingItemId === null && $this->rejectFixedQuran($curriculum)) {
            return;
        }

        $validated = $this->validate([
            'itemName' => ['required', 'string', 'max:255'],
            'itemCode' => [
                'nullable', 'string', 'max:64',
                Rule::unique('curriculum_items', 'code')
                    ->where('curriculum_id', $this->itemCurriculumId)
                    ->ignore($this->editingItemId),
            ],
            'itemSortOrder' => ['integer', 'min:0'],
            'itemCount' => ['nullable', 'integer', 'min:0', 'max:10000'],
        ], attributes: ['itemName' => 'اسم البند', 'itemCode' => 'الرمز', 'itemCount' => 'العدّاد']);

        app(SaveCurriculumItem::class)->handle(
            $curriculum,
            [
                'name' => $validated['itemName'],
                'code' => $validated['itemCode'],
                'sort_order' => $validated['itemSortOrder'],
                'meta' => $this->metaFor($curriculum, $validated['itemCount']),
            ],
            $this->editingItemId,
        );

        unset($this->curricula, $this->itemCurriculum);
        Flux::modal('item-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ البند.');
    }

    public function deleteItem(CurriculumItem $item): void
    {
        if ($this->rejectFixedQuran($item->curriculum)) {
            return;
        }

        if ($item->progress()->exists()) {
            Flux::toast(variant: 'danger', text: 'لا يمكن حذف بند مرتبط بسجل محفوظات.');

            return;
        }

        $item->delete();

        unset($this->curricula);
        Flux::toast(variant: 'success', text: 'حُذف البند.');
    }

    /**
     * أجزاء القرآن ثلاثون ثابتاً — إخفاء الأزرار وحده ليس حماية، فالحراسة هنا على الخادم.
     */
    private function rejectFixedQuran(Curriculum $curriculum): bool
    {
        if ($curriculum->type !== CurriculumType::Quran) {
            return false;
        }

        Flux::toast(variant: 'danger', text: 'أجزاء القرآن ثابتة ولا تُضاف ولا تُحذف.');

        return true;
    }

    /**
     * مفتاح العدّاد يتبع نوع المنهج: الأحاديث للحديث، والأبيات للمتون، ولا عدّاد لسواهما.
     *
     * @return array<string, mixed>
     */
    private function metaFor(Curriculum $curriculum, ?int $count): array
    {
        $key = self::countKey($curriculum->type);

        return $key === null ? [] : [$key => $count];
    }

    private function countOf(CurriculumItem $item): ?int
    {
        $key = self::countKey($item->curriculum->type);

        return $key === null ? null : ($item->meta[$key] ?? null);
    }

    private static function countKey(?CurriculumType $type): ?string
    {
        return match ($type) {
            CurriculumType::Hadith => 'hadiths',
            CurriculumType::Mutun => 'abyat',
            default => null,
        };
    }

    public function delete(Curriculum $curriculum): void
    {
        if ($curriculum->items()->whereHas('progress')->exists()) {
            Flux::toast(variant: 'danger', text: 'لا يمكن حذف منهج له بنود مرتبطة بسجل محفوظات.');

            return;
        }

        $curriculum->delete();

        unset($this->curricula);
        Flux::toast(variant: 'success', text: 'حُذف المنهج.');
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
                        @if ($curriculum->type !== CurriculumType::Quran)
                            <flux:button wire:click="createItem('{{ $curriculum->uuid }}')" size="sm" icon="plus">بند</flux:button>
                        @endif
                        <flux:button wire:click="edit('{{ $curriculum->uuid }}')" size="sm" variant="subtle" icon="pencil">تعديل</flux:button>
                        @if ($curriculum->institute_id !== null)
                            <flux:button
                                wire:click="delete('{{ $curriculum->uuid }}')"
                                wire:confirm="حذف هذا المنهج نهائياً؟"
                                size="sm"
                                variant="subtle"
                                icon="trash"
                                data-test="delete-curriculum"
                            >حذف</flux:button>
                        @endif
                    </div>
                </div>

                <div class="flex flex-wrap gap-2 p-4">
                    @forelse ($curriculum->items as $item)
                        @php
                            $count = match ($curriculum->type) {
                                CurriculumType::Hadith => $item->meta['hadiths'] ?? null,
                                CurriculumType::Mutun => $item->meta['abyat'] ?? null,
                                default => null,
                            };
                            $countLabel = $count === null ? null : $count.($curriculum->type === CurriculumType::Hadith ? ' حديثاً' : ' بيتاً');
                        @endphp

                        <flux:badge wire:key="item-{{ $item->id }}" color="zinc">
                            <button type="button" wire:click="editItem('{{ $item->uuid }}')" class="cursor-pointer">
                                {{ $item->name }}@if ($countLabel)<span class="latin-numerals text-ink-500 dark:text-zinc-400"> · {{ $countLabel }}</span>@endif
                            </button>
                            @if ($curriculum->type !== CurriculumType::Quran)
                                <flux:badge.close wire:click="deleteItem('{{ $item->uuid }}')" />
                            @endif
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

            @php($countLabel = match ($this->itemCurriculum?->type) {
                CurriculumType::Hadith => 'عدد الأحاديث',
                CurriculumType::Mutun => 'عدد الأبيات',
                default => null,
            })

            @if ($countLabel)
                <flux:input
                    wire:model="itemCount"
                    type="number"
                    min="0"
                    :label="$countLabel"
                    class="latin-numerals"
                    description="يُضرب في معامل النقاط عند احتساب إنجاز البند"
                    data-test="curriculum-item-count"
                />
            @endif

            <flux:input wire:model="itemSortOrder" type="number" label="ترتيب العرض" min="0" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-curriculum-item">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
