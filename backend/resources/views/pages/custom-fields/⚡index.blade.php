<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\CustomFieldType;
use App\Models\CustomField;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('الواصفات المخصّصة')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $entity = 'student';

    public string $label = '';

    public string $key = '';

    public string $type = 'text';

    public string $optionsText = '';

    public string $group = '';

    public bool $is_required = false;

    public bool $is_active = true;

    public int $sort_order = 0;

    /**
     * @var array<string, string>
     */
    public const ENTITIES = [
        'student' => 'الطالب',
        'teacher' => 'الأستاذ',
        'circle' => 'الحلقة',
    ];

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, CustomField>
     */
    #[Computed]
    public function fields(): Collection
    {
        return CustomField::query()
            ->where('institute_id', $this->institute->id)
            ->orderBy('entity')
            ->orderBy('sort_order')
            ->get();
    }

    public function create(): void
    {
        $this->reset('editingId', 'label', 'key', 'optionsText', 'group');
        $this->entity = 'student';
        $this->type = CustomFieldType::Text->value;
        $this->is_required = false;
        $this->is_active = true;
        $this->sort_order = $this->fields->count();
        $this->resetValidation();

        Flux::modal('field-form')->show();
    }

    public function edit(CustomField $field): void
    {
        $this->editingId = $field->id;
        $this->entity = $field->entity;
        $this->label = $field->label;
        $this->key = $field->key;
        $this->type = $field->type->value;
        $this->optionsText = implode("\n", $field->options ?? []);
        $this->group = (string) $field->group;
        $this->is_required = $field->is_required;
        $this->is_active = $field->is_active;
        $this->sort_order = $field->sort_order;
        $this->resetValidation();

        Flux::modal('field-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'entity' => ['required', Rule::in(array_keys(self::ENTITIES))],
            'label' => ['required', 'string', 'max:255'],
            'key' => ['nullable', 'string', 'max:64', 'regex:/^[a-z0-9_]*$/'],
            'type' => ['required', Rule::enum(CustomFieldType::class)],
            'optionsText' => ['nullable', 'string'],
            'group' => ['nullable', 'string', 'max:64'],
            'is_required' => ['boolean'],
            'is_active' => ['boolean'],
            'sort_order' => ['integer', 'min:0'],
        ], attributes: ['label' => 'اسم الواصفة', 'key' => 'المفتاح البرمجي']);

        $options = collect(explode("\n", $validated['optionsText'] ?? ''))
            ->map(fn (string $line) => trim($line))
            ->filter()
            ->values()
            ->all();

        CustomField::updateOrCreate(
            ['id' => $this->editingId],
            [
                'institute_id' => $this->institute->id,
                'entity' => $validated['entity'],
                'label' => $validated['label'],
                'key' => $validated['key'] ?: Str::slug($validated['label'], '_'),
                'type' => $validated['type'],
                'options' => $options ?: null,
                'group' => $validated['group'] ?: null,
                'is_required' => $validated['is_required'],
                'is_active' => $validated['is_active'],
                'sort_order' => $validated['sort_order'],
            ],
        );

        unset($this->fields);
        Flux::modal('field-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظت الواصفة.');
    }

    public function delete(CustomField $field): void
    {
        $field->delete();

        unset($this->fields);
        Flux::toast(variant: 'success', text: 'حُذفت الواصفة.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الواصفات المخصّصة" subheading="حقول إضافية يعرّفها المشرف وتظهر في استمارات الطلاب والأساتذة والحلقات">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-custom-field">واصفة جديدة</flux:button>
        </x-slot>
    </x-page-header>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->fields->isEmpty())
            <flux:text class="p-6 text-center">لم تُعرَّف واصفات مخصّصة بعد.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الواصفة</flux:table.column>
                    <flux:table.column>الكيان</flux:table.column>
                    <flux:table.column>النوع</flux:table.column>
                    <flux:table.column>المفتاح</flux:table.column>
                    <flux:table.column>إلزامية</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->fields as $field)
                        <flux:table.row :key="$field->id">
                            <flux:table.cell>{{ $field->label }}</flux:table.cell>
                            <flux:table.cell>{{ self::ENTITIES[$field->entity] ?? $field->entity }}</flux:table.cell>
                            <flux:table.cell>{{ $field->type->label() }}</flux:table.cell>
                            <flux:table.cell><code class="text-xs">{{ $field->key }}</code></flux:table.cell>
                            <flux:table.cell>{{ $field->is_required ? 'نعم' : 'لا' }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="edit({{ $field->id }})" icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete({{ $field->id }})" icon="trash" variant="danger">حذف</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="field-form" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل الواصفة' : 'واصفة جديدة' }}</flux:heading>

            <flux:input wire:model="label" label="اسم الواصفة" required />

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:select wire:model="entity" label="تظهر في استمارة">
                    @foreach (self::ENTITIES as $value => $entityLabel)
                        <flux:select.option value="{{ $value }}">{{ $entityLabel }}</flux:select.option>
                    @endforeach
                </flux:select>

                <flux:select wire:model.live="type" label="النوع">
                    @foreach (CustomFieldType::options() as $value => $typeLabel)
                        <flux:select.option value="{{ $value }}">{{ $typeLabel }}</flux:select.option>
                    @endforeach
                </flux:select>
            </div>

            @if (in_array($type, [CustomFieldType::Select->value, CustomFieldType::MultiSelect->value], true))
                <flux:textarea wire:model="optionsText" label="الخيارات" description="خيار في كل سطر" rows="4" />
            @endif

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="key" label="المفتاح البرمجي" description="أحرف لاتينية صغيرة وشرطة سفلية — يُولَّد تلقائياً إن تُرك فارغاً" />
                <flux:input wire:model="group" label="المجموعة" />
            </div>

            <flux:input wire:model="sort_order" type="number" label="ترتيب العرض" min="0" />

            <div class="flex gap-6">
                <flux:switch wire:model="is_required" label="إلزامية" />
                <flux:switch wire:model="is_active" label="فعّالة" />
            </div>

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-custom-field">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
