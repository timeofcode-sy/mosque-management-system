<?php

use App\Actions\ChangeUserPassword;
use App\Concerns\InteractsWithInstitute;
use App\Enums\PanelRole;
use App\Models\CourseCircle;
use App\Models\User;
use App\Queries\CredentialQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;

/**
 * بيانات الدخول: عرضُها وتبديلُها وتسليمُها.
 *
 * كلمات المرور مخفيّة افتراضاً وتُكشف بمفتاح واحد — الشاشة تُفتح أمام قاعة فيها
 * طلاب، وكشفُ عمودٍ كامل بلا قصد تسريبٌ لحلقةٍ بأكملها.
 *
 * القيود كلها في CredentialQuery و ChangeUserPassword لا هنا: الرتبة تحكم من تُرى
 * بياناتُه ومن تُبدَّل كلمتُه، والواجهة تعرض ما يُرجَع إليها لا أكثر.
 */
new #[Title('بيانات الدخول')] class extends Component {
    use InteractsWithInstitute;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    #[Url(except: '')]
    public string $role = '';

    #[Url(except: '')]
    public string $circle = '';

    public bool $revealed = false;

    /** تبديل كلمة مرور حساب بعينه */
    public ?int $targetUserId = null;

    public string $targetName = '';

    public string $new_password = '';

    public ?string $issuedPassword = null;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    #[Computed]
    public function rows(): Collection
    {
        if ($this->institute === null) {
            return new Collection;
        }

        return app(CredentialQuery::class)->rows(
            $this->institute,
            auth()->user(),
            $this->role,
            $this->search,
            $this->circle === '' ? null : (int) $this->circle,
        );
    }

    /**
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function circles(): Collection
    {
        return $this->currentCourse?->courseCircles()->with('circle')->get() ?? new Collection;
    }

    /**
     * @return array<int, PanelRole>
     */
    #[Computed]
    public function roles(): array
    {
        return CredentialQuery::roles();
    }

    /**
     * المرشّحات نفسها تُمرَّر إلى التصدير والطباعة فتخرج القائمةُ المعروضة بعينها.
     *
     * @return array<string, string>
     */
    #[Computed]
    public function exportParameters(): array
    {
        return array_filter([
            'q' => $this->search,
            'role' => $this->role,
            'circle' => $this->circle,
        ]);
    }

    public function openPasswordForm(int $userId, string $name): void
    {
        $this->targetUserId = $userId;
        $this->targetName = $name;
        $this->new_password = '';
        $this->issuedPassword = null;
        $this->resetValidation();

        Flux::modal('change-password')->show();
    }

    /**
     * كلمةٌ يكتبها المشرف، أو ثمانيةُ أرقام يولّدها النظام إن تُرك الحقل فارغاً.
     */
    public function changePassword(): void
    {
        $validated = $this->validate([
            'new_password' => ['nullable', 'string', 'min:8', 'max:64'],
        ], attributes: ['new_password' => 'كلمة المرور']);

        try {
            $this->issuedPassword = app(ChangeUserPassword::class)->handle(
                auth()->user(),
                User::findOrFail($this->targetUserId),
                $validated['new_password'] ?: null,
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->rows);
        Flux::toast(variant: 'success', text: 'بُدّلت كلمة المرور.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="بيانات الدخول" subheading="أسماء المستخدمين وكلمات المرور للطباعة والتوزيع">
        <x-slot name="actions">
            <flux:button
                :href="route('credentials.print', $this->exportParameters)"
                target="_blank"
                icon="printer"
                variant="ghost"
                data-test="print-credentials"
            >طباعة البطاقات</flux:button>

            <flux:button
                :href="route('credentials.csv', $this->exportParameters)"
                icon="arrow-down-tray"
                variant="primary"
                data-test="export-credentials"
            >تصدير CSV</flux:button>
        </x-slot>
    </x-page-header>

    <div class="flex flex-wrap items-end gap-4">
        <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بالاسم أو اسم المستخدم" class="sm:max-w-xs" />

        <flux:select wire:model.live="role" class="sm:max-w-40">
            <flux:select.option value="">كل الأدوار</flux:select.option>
            @foreach ($this->roles as $panelRole)
                <flux:select.option value="{{ $panelRole->value }}">{{ $panelRole->label() }}</flux:select.option>
            @endforeach
        </flux:select>

        @if ($this->circles->isNotEmpty())
            <flux:select wire:model.live="circle" class="sm:max-w-56">
                <flux:select.option value="">كل الحلقات</flux:select.option>
                @foreach ($this->circles as $courseCircle)
                    <flux:select.option value="{{ $courseCircle->id }}">{{ $courseCircle->circle->name }}</flux:select.option>
                @endforeach
            </flux:select>
        @endif

        <flux:switch wire:model.live="revealed" label="إظهار كلمات المرور" />
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->rows->isEmpty())
            <flux:text class="p-6 text-center">لا توجد بيانات دخول مطابقة.</flux:text>
        @else
            <flux:table>
                <flux:table.columns>
                    <flux:table.column>الاسم</flux:table.column>
                    <flux:table.column>الدور</flux:table.column>
                    <flux:table.column>اسم المستخدم</flux:table.column>
                    <flux:table.column>كلمة المرور</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->rows as $row)
                        <flux:table.row :key="$row['id']">
                            <flux:table.cell>{{ $row['name'] }}</flux:table.cell>
                            <flux:table.cell>{{ $row['role'] }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $row['username'] }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">
                                @if ($row['password'] === null)
                                    <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">غيّرها صاحبها</flux:text>
                                @elseif ($revealed)
                                    {{ $row['password'] }}
                                @else
                                    ••••••••
                                @endif
                            </flux:table.cell>
                            <flux:table.cell>
                                <flux:badge size="sm" :color="$row['is_active'] ? 'lime' : 'zinc'">
                                    {{ $row['is_active'] ? 'نشط' : 'مقفل' }}
                                </flux:badge>
                            </flux:table.cell>
                            <flux:table.cell>
                                @can('credentials.manage')
                                    <flux:button
                                        wire:click="openPasswordForm({{ $row['id'] }}, @js($row['name']))"
                                        size="sm"
                                        variant="subtle"
                                        icon="key"
                                        data-test="change-password"
                                    >تبديل</flux:button>
                                @endcan
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="change-password" class="w-full max-w-md">
        <form wire:submit="changePassword" class="space-y-6">
            <flux:heading size="lg">كلمة مرور {{ $targetName }}</flux:heading>

            @if ($issuedPassword)
                <flux:callout icon="key" variant="success">
                    <flux:callout.heading>كلمة المرور الجديدة</flux:callout.heading>
                    <flux:input readonly :value="$issuedPassword" class="latin-numerals mt-3" data-test="issued-password" />
                </flux:callout>

                <flux:modal.close><flux:button variant="primary">تمّ</flux:button></flux:modal.close>
            @else
                <flux:input
                    wire:model="new_password"
                    label="كلمة مرور جديدة"
                    description="اتركه فارغاً ليولّد النظام ثمانية أرقام"
                    class="latin-numerals"
                />

                <div class="flex gap-2">
                    <flux:button type="submit" variant="primary" data-test="save-password">تبديل</flux:button>
                    <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                </div>
            @endif
        </form>
    </flux:modal>
</div>
