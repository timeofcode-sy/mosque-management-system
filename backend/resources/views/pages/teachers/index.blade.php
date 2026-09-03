<?php

use App\Actions\InviteUser;
use App\Concerns\InteractsWithInstitute;
use App\Enums\PanelRole;
use App\Enums\TeacherStatus;
use App\Models\Teacher;
use App\Queries\InstituteCatalogQuery;
use Flux\Flux;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

new #[Title('الأساتذة')] class extends Component {
    use InteractsWithInstitute, WithPagination;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    public ?int $editingId = null;

    public string $display_name = '';

    public string $phone = '';

    public string $national_id = '';

    public string $birth_date = '';

    public string $specialization = '';

    public string $qualification = '';

    public string $address = '';

    public string $hired_on = '';

    public string $status = 'active';

    public string $notes = '';

    /** «إنشاء حساب دخول» — يربط سجلّ الأستاذ بحساب ليعمل تطبيق الأستاذ. */
    public ?int $accountTeacherId = null;

    public string $account_email = '';

    public ?string $inviteLink = null;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    /**
     * @return LengthAwarePaginator<int, Teacher>
     */
    #[Computed]
    public function teachers(): LengthAwarePaginator
    {
        return app(InstituteCatalogQuery::class)->teachers($this->institute, $this->currentCourse, $this->search);
    }

    public function create(): void
    {
        $this->reset('editingId', 'display_name', 'phone', 'national_id', 'birth_date', 'specialization', 'qualification', 'address', 'hired_on', 'notes');
        $this->status = TeacherStatus::Active->value;
        $this->resetValidation();

        Flux::modal('teacher-form')->show();
    }

    public function edit(Teacher $teacher): void
    {
        $this->editingId = $teacher->id;
        $this->display_name = $teacher->display_name;
        $this->phone = (string) $teacher->phone;
        $this->national_id = (string) $teacher->national_id;
        $this->birth_date = $teacher->birth_date?->toDateString() ?? '';
        $this->specialization = (string) $teacher->specialization;
        $this->qualification = (string) $teacher->qualification;
        $this->address = (string) $teacher->address;
        $this->hired_on = $teacher->hired_on?->toDateString() ?? '';
        $this->status = $teacher->status->value;
        $this->notes = (string) $teacher->notes;
        $this->resetValidation();

        Flux::modal('teacher-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'display_name' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:32'],
            'national_id' => ['nullable', 'string', 'max:32'],
            'birth_date' => ['nullable', 'date', 'before:today'],
            'specialization' => ['nullable', 'string', 'max:255'],
            'qualification' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'hired_on' => ['nullable', 'date'],
            'status' => ['required', Rule::enum(TeacherStatus::class)],
            'notes' => ['nullable', 'string'],
        ], attributes: ['display_name' => 'اسم الأستاذ']);

        $attributes = collect($validated)->map(fn ($value) => $value === '' ? null : $value)->all();

        Teacher::updateOrCreate(
            ['id' => $this->editingId],
            [...$attributes, 'institute_id' => $this->institute->id],
        );

        unset($this->teachers);
        Flux::modal('teacher-form')->close();
        Flux::toast(variant: 'success', text: 'حُفظ الأستاذ.');
    }

    public function delete(Teacher $teacher): void
    {
        $teacher->delete();

        unset($this->teachers);
        Flux::toast(variant: 'success', text: 'حُذف الأستاذ.');
    }

    /**
     * إنشاء حساب دخول لأستاذ قائم وربطه بسجلّه.
     *
     * الربط شرطُ تشغيل تطبيق الأستاذ: ApiScope يشتقّ المعهد من teachers.user_id،
     * وحسابٌ بلا سجلّ يُرفض بـ 422.
     */
    public function createAccount(Teacher $teacher): void
    {
        $this->accountTeacherId = $teacher->id;
        $this->account_email = '';
        $this->inviteLink = null;
        $this->resetValidation();

        Flux::modal('teacher-account')->show();
    }

    public function saveAccount(): void
    {
        $validated = $this->validate([
            'account_email' => ['required', 'email', 'max:255', 'unique:users,email'],
        ], attributes: ['account_email' => 'البريد الإلكتروني']);

        $teacher = Teacher::findOrFail($this->accountTeacherId);
        $parts = preg_split('/\s+/u', trim($teacher->display_name), 2) ?: [$teacher->display_name];

        try {
            $result = app(InviteUser::class)->handle(
                auth()->user(),
                [
                    'first_name' => $parts[0],
                    'last_name' => $parts[1] ?? $parts[0],
                    'email' => $validated['account_email'],
                    'phone' => $teacher->phone,
                ],
                PanelRole::Teacher,
                $this->institute,
                $teacher,
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        $this->inviteLink = $result['reset_url'];

        unset($this->teachers);
        Flux::toast(variant: 'success', text: 'أُنشئ حساب الأستاذ — انسخ رابط تعيين كلمة المرور.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الأساتذة" :subheading="$this->institute?->name">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-teacher">أستاذ جديد</flux:button>
        </x-slot>
    </x-page-header>

    <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بالاسم أو الهاتف أو التخصّص" class="sm:max-w-md" />

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->teachers->isEmpty())
            <flux:text class="p-6 text-center">لا يوجد أساتذة مطابقون.</flux:text>
        @else
            <flux:table :paginate="$this->teachers">
                <flux:table.columns>
                    <flux:table.column>الأستاذ</flux:table.column>
                    <flux:table.column>الهاتف</flux:table.column>
                    <flux:table.column>التخصّص</flux:table.column>
                    <flux:table.column>حلقات الدورة الجارية</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->teachers as $teacher)
                        <flux:table.row :key="$teacher->id">
                            <flux:table.cell>{{ $teacher->display_name }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $teacher->phone ?: '—' }}</flux:table.cell>
                            <flux:table.cell>{{ $teacher->specialization ?: '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $teacher->current_circles_count }}</flux:table.cell>
                            <flux:table.cell>{{ $teacher->status->label() }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="edit('{{ $teacher->uuid }}')" icon="pencil">تعديل</flux:menu.item>

                                        @can('users.invite')
                                            @if ($teacher->user_id === null)
                                                <flux:menu.item wire:click="createAccount('{{ $teacher->uuid }}')" icon="key">إنشاء حساب دخول</flux:menu.item>
                                            @endif
                                        @endcan

                                        <flux:menu.separator />
                                        <flux:menu.item wire:click="delete('{{ $teacher->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="teacher-form" class="w-full max-w-2xl">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">{{ $editingId ? 'تعديل بيانات الأستاذ' : 'أستاذ جديد' }}</flux:heading>

            <div class="grid gap-6 sm:grid-cols-2">
                <flux:input wire:model="display_name" label="اسم الأستاذ" required />
                <flux:input wire:model="phone" label="الجوال" />
                <flux:input wire:model="national_id" label="الرقم الوطني" />
                <flux:input wire:model="birth_date" type="date" label="تاريخ الولادة" />
                <flux:input wire:model="specialization" label="التخصّص" />
                <flux:input wire:model="qualification" label="المؤهّل العلمي" />
                <flux:input wire:model="address" label="العنوان" />
                <flux:input wire:model="hired_on" type="date" label="تاريخ المباشرة" />

                <flux:select wire:model="status" label="الحالة">
                    @foreach (TeacherStatus::options() as $value => $label)
                        <flux:select.option value="{{ $value }}">{{ $label }}</flux:select.option>
                    @endforeach
                </flux:select>
            </div>

            <flux:textarea wire:model="notes" label="ملاحظات" rows="2" />

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-teacher">حفظ</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="teacher-account" class="w-full max-w-lg">
        <form wire:submit="saveAccount" class="space-y-6">
            <flux:heading size="lg">إنشاء حساب دخول</flux:heading>

            @if ($inviteLink)
                <flux:callout icon="link" variant="success">
                    <flux:callout.heading>أُنشئ الحساب ورُبط بسجلّ الأستاذ</flux:callout.heading>
                    <flux:callout.text>انسخ الرابط وسلّمه للأستاذ ليعيّن كلمة مروره — لن يُعرض مرّةً أخرى.</flux:callout.text>
                    <flux:input readonly :value="$inviteLink" class="latin-numerals mt-3" data-test="teacher-invite-link" />
                </flux:callout>

                <flux:modal.close><flux:button variant="primary">تمّ</flux:button></flux:modal.close>
            @else
                <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">
                    يُسنَد للحساب دور «أستاذ» داخل هذا المعهد، ويُربط بسجلّه — وهذا شرط تشغيل تطبيق الأستاذ.
                </flux:text>

                <flux:input wire:model="account_email" type="email" label="البريد الإلكتروني" required data-test="teacher-account-email" />

                <div class="flex gap-2">
                    <flux:button type="submit" variant="primary" data-test="save-teacher-account">إنشاء</flux:button>
                    <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                </div>
            @endif
        </form>
    </flux:modal>
</div>
