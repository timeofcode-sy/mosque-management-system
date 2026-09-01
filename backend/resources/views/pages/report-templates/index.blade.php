<?php

use App\Actions\RenderReportTemplate;
use App\Concerns\InteractsWithInstitute;
use App\Enums\ReportScope;
use App\Models\ReportTemplate;
use App\Queries\ReportTemplateQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

new #[Title('قوالب التقارير')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $name = '';

    public string $key = '';

    public string $scope = 'circle';

    public string $body = '';

    public bool $is_active = true;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, ReportTemplate>
     */
    #[Computed]
    public function templates(): Collection
    {
        return app(ReportTemplateQuery::class)->forInstitute($this->institute);
    }

    /**
     * معاينة القالب بقيم مثال — يرى المشرف شكل الرسالة قبل حفظها.
     */
    #[Computed]
    public function preview(): string
    {
        return app(RenderReportTemplate::class)->render($this->body, [
            'institute_name' => $this->institute?->name ?? 'معهد النور',
            'course_name' => 'الدورة الصيفية',
            'circle_name' => 'حلقة الفاروق',
            'shift_name' => 'الدوام الصباحي',
            'room' => 'القاعة 2',
            'teacher_names' => 'الأستاذ عبد الرحمن',
            'date' => now()->toDateString(),
            'date_hijri' => App\Support\HijriDate::long(now()) ?? '—',
            'weekday' => App\Enums\Weekday::from(now()->dayOfWeek)->label(),
            'present' => '18',
            'absent' => '2',
            'late' => '1',
            'excused' => '1',
            'total' => '22',
            'rate' => '90.5%',
            'daily_rank' => '2',
            'overall_rank' => '1',
            'sessions_count' => '14',
            'overall_rate' => '92.3%',
            'present_list' => 'محمد أحمد، عمر خالد، …',
            'absent_list' => 'سعيد وليد، ياسر نبيل',
            'late_list' => 'أنس فادي',
            'excused_list' => 'زيد سامر',
        ]);
    }

    public function create(): void
    {
        $this->reset('editingId', 'name', 'key', 'body');
        $this->scope = 'circle';
        $this->is_active = true;
        $this->resetValidation();

        Flux::modal('template-form')->show();
    }

    public function edit(ReportTemplate $reportTemplate): void
    {
        $this->editingId = $reportTemplate->id;
        $this->name = $reportTemplate->name;
        $this->key = $reportTemplate->key;
        $this->scope = $reportTemplate->scope->value;
        $this->body = $reportTemplate->body;
        $this->is_active = $reportTemplate->is_active;
        $this->resetValidation();

        Flux::modal('template-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'key' => [
                'nullable', 'string', 'max:64', 'regex:/^[a-z0-9_]*$/',
                Rule::unique('report_templates', 'key')
                    ->where('institute_id', $this->institute?->id)
                    ->ignore($this->editingId),
            ],
            'scope' => ['required', Rule::enum(ReportScope::class)],
            'body' => ['required', 'string'],
            'is_active' => ['boolean'],
        ], attributes: [
            'name' => 'اسم القالب',
            'key' => 'المفتاح',
            'body' => 'نص القالب',
        ]);

        ReportTemplate::updateOrCreate(
            ['id' => $this->editingId],
            [
                ...$validated,
                'institute_id' => $this->institute->id,
                'key' => $validated['key'] ?: Str::slug($validated['name'], '_') ?: Str::random(8),
            ],
        );

        unset($this->templates);
        Flux::modal('template-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ القالب.');
    }

    public function delete(ReportTemplate $reportTemplate): void
    {
        $reportTemplate->delete();

        unset($this->templates);
        Flux::toast(variant: 'success', text: 'حُذف القالب.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header
        heading="قوالب التقارير"
        subheading="نصوص جاهزة بمتغيّرات تُملأ تلقائياً — تُستعمل في التقارير اليومية ورسائل أولياء الأمور"
    >
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-template">قالب جديد</flux:button>
        </x-slot>
    </x-page-header>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->templates->isEmpty())
            <flux:text class="p-6 text-center">لا توجد قوالب بعد.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>القالب</flux:table.column>
                    <flux:table.column>المفتاح</flux:table.column>
                    <flux:table.column>النطاق</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->templates as $template)
                        <flux:table.row :key="$template->id">
                            <flux:table.cell>{{ $template->name }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $template->key }}</flux:table.cell>
                            <flux:table.cell>{{ $template->scope->label() }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:badge size="sm" :color="$template->is_active ? 'green' : 'zinc'">
                                    {{ $template->is_active ? 'مفعّل' : 'موقوف' }}
                                </flux:badge>
                            </flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="edit('{{ $template->uuid }}')" icon="pencil">تعديل</flux:menu.item>
                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete('{{ $template->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="template-form" class="w-full max-w-3xl">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل القالب' : 'قالب جديد' }}</flux:heading>

            <div class="grid gap-4 sm:grid-cols-3">
                <flux:input wire:model="name" label="اسم القالب" class="sm:col-span-2" />
                <flux:select wire:model="scope" label="النطاق">
                    @foreach (ReportScope::options() as $value => $label)
                        <flux:select.option :value="$value">{{ $label }}</flux:select.option>
                    @endforeach
                </flux:select>
            </div>

            <flux:input wire:model="key" label="المفتاح" description="حروف لاتينية صغيرة وشرطة سفلية — يُشتقّ من الاسم إن تُرك فارغاً" class="latin-numerals" />

            <flux:textarea wire:model.live.debounce.500ms="body" label="نص القالب" rows="6" data-test="template-body" />

            <div>
                <flux:heading size="sm">المتغيّرات المتاحة</flux:heading>
                <div class="mt-2 flex flex-wrap gap-1.5">
                    @foreach (App\Actions\RenderReportTemplate::VARIABLES as $variable => $label)
                        {{-- @{{ ... }} تمنع Blade من تفسير القوسين، فيظهر اسم المتغيّر كما يكتبه المشرف --}}
                        <flux:badge size="sm" color="zinc" class="latin-numerals" :title="$label">@{{ {{ $variable }} }}</flux:badge>
                    @endforeach
                </div>
            </div>

            @if (trim($body) !== '')
                <div>
                    <flux:heading size="sm">المعاينة</flux:heading>
                    <div class="mt-2 whitespace-pre-wrap rounded-lg border border-sand-200 bg-sand-50 p-4 text-sm dark:border-zinc-700 dark:bg-zinc-800" data-test="template-preview">{{ $this->preview }}</div>
                </div>
            @endif

            <flux:switch wire:model="is_active" label="مفعّل" />

            <div class="flex justify-end gap-2">
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                <flux:button type="submit" variant="primary" data-test="save-template">حفظ</flux:button>
            </div>
        </form>
    </flux:modal>
</div>
