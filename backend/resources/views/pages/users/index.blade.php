<?php

use App\Actions\AssignUserRole;
use App\Actions\ChangeUserPassword;
use App\Actions\InviteUser;
use App\Actions\RevokeUserRole;
use App\Actions\ToggleUserActivation;
use App\Enums\PanelRole;
use App\Models\Institute;
use App\Models\User;
use App\Queries\UserAdminQuery;
use App\Support\PanelScope;
use Flux\Flux;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * المستخدمون وأدوارهم. الحراسة كلها في الإجراءات (AssignUserRole) لا هنا —
 * القائمة تُبنى من الأدوار المتاحة كي لا يرى المستخدم ما لا يملكه، لكنّ الرفض
 * الحقيقي يقع على الخادم.
 *
 * الإنشاء اليدوي مقصورٌ على الأدوار الإدارية (creatableRoles): مدير المعهد يرى
 * «مدير معهد» و«مشرف» لا غير. أما الأستاذ وولي الأمر والطالب فحساباتهم تولَّد مع
 * سجلّاتها في App\Observers، وتُدار من شاشة «بيانات الدخول».
 */
new #[Title('المستخدمون')] class extends Component {
    use WithPagination;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    #[Url(except: '')]
    public string $role = '';

    #[Url(except: '')]
    public string $institute = '';

    /** نموذج الدعوة */
    public string $first_name = '';

    public string $last_name = '';

    public string $email = '';

    public string $phone = '';

    public string $new_role = '';

    public string $new_institute = '';

    /**
     * بيانات الدخول المولَّدة — تُعرض مرّةً بعد الإنشاء. لا قناة بريد في المشروع،
     * فالنسخ اليدوي هو التسليم.
     *
     * @var array{username: ?string, password: string}|null
     */
    public ?array $issuedCredentials = null;

    /** إسناد دور لمستخدم قائم */
    public ?int $targetUserId = null;

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    /**
     * @return LengthAwarePaginator<int, User>
     */
    #[Computed]
    public function users(): LengthAwarePaginator
    {
        return app(UserAdminQuery::class)->list(
            $this->search,
            $this->role,
            $this->institute === '' ? null : (int) $this->institute,
        );
    }

    /**
     * @return Collection<int, array<int, array{role: string, institute_id: int, institute: string|null}>>
     */
    #[Computed]
    public function assignments(): Collection
    {
        return app(UserAdminQuery::class)->roleAssignments($this->users->pluck('id')->all());
    }

    /**
     * @return array<int, PanelRole>
     */
    #[Computed]
    public function assignableRoles(): array
    {
        return AssignUserRole::assignableRoles(auth()->user());
    }

    /**
     * @return array<int, PanelRole>
     */
    #[Computed]
    public function creatableRoles(): array
    {
        return AssignUserRole::creatableRoles(auth()->user());
    }

    /**
     * @return Collection<int, Institute>
     */
    #[Computed]
    public function institutes(): Collection
    {
        return PanelScope::institutesFor(auth()->user());
    }

    public function invite(): void
    {
        $this->reset('first_name', 'last_name', 'email', 'phone', 'new_role', 'new_institute', 'issuedCredentials', 'targetUserId');
        $this->new_institute = (string) (PanelScope::resolve()?->id ?? '');
        $this->resetValidation();

        Flux::modal('invite-user')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'first_name' => ['required', 'string', 'max:255'],
            'last_name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:32'],
            'new_role' => ['required', Rule::in(collect($this->creatableRoles)->map->value->all())],
            'new_institute' => ['nullable', Rule::in($this->institutes->modelKeys())],
        ], attributes: [
            'first_name' => 'الاسم', 'last_name' => 'الكنية', 'email' => 'البريد',
            'new_role' => 'الدور', 'new_institute' => 'المعهد',
        ]);

        $role = PanelRole::from($validated['new_role']);

        try {
            $result = app(InviteUser::class)->handle(
                auth()->user(),
                [
                    'first_name' => $validated['first_name'],
                    'last_name' => $validated['last_name'],
                    'email' => $validated['email'] ?: null,
                    'phone' => $validated['phone'] ?: null,
                ],
                $role,
                $role->isGlobal() ? null : Institute::find($validated['new_institute'] ?: null),
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        $this->issuedCredentials = [
            'username' => $result['user']->username,
            'password' => $result['password'],
        ];

        unset($this->users, $this->assignments);

        Flux::toast(variant: 'success', text: 'أُنشئ الحساب — انسخ بيانات الدخول.');
    }

    public function openRoleForm(User $user): void
    {
        $this->targetUserId = $user->id;
        $this->new_role = '';
        $this->new_institute = (string) (PanelScope::resolve()?->id ?? '');
        $this->resetValidation();

        Flux::modal('assign-role')->show();
    }

    public function assign(): void
    {
        $validated = $this->validate([
            'new_role' => ['required', Rule::in(collect($this->assignableRoles)->map->value->all())],
            'new_institute' => ['nullable', Rule::in($this->institutes->modelKeys())],
        ], attributes: ['new_role' => 'الدور', 'new_institute' => 'المعهد']);

        $role = PanelRole::from($validated['new_role']);

        try {
            app(AssignUserRole::class)->handle(
                auth()->user(),
                User::findOrFail($this->targetUserId),
                $role,
                $role->isGlobal() ? null : Institute::find($validated['new_institute'] ?: null),
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->users, $this->assignments);
        Flux::modal('assign-role')->close();
        Flux::toast(variant: 'success', text: 'أُسند الدور.');
    }

    public function revoke(int $userId, string $roleName, int $instituteId): void
    {
        try {
            app(RevokeUserRole::class)->handle(
                auth()->user(),
                User::findOrFail($userId),
                PanelRole::from($roleName),
                $instituteId === User::GLOBAL_TEAM_ID ? null : Institute::find($instituteId),
            );
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->users, $this->assignments);
        Flux::toast(variant: 'success', text: 'سُحب الدور.');
    }

    /**
     * تبديل كلمة مرور حساب — بتوليد ثمانية أرقام جديدة.
     */
    public function resetPassword(int $userId): void
    {
        try {
            $user = User::findOrFail($userId);
            $password = app(ChangeUserPassword::class)->handle(auth()->user(), $user);
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        $this->issuedCredentials = ['username' => $user->username, 'password' => $password];

        Flux::modal('issued-credentials')->show();
    }

    public function toggleActivation(int $userId, bool $active): void
    {
        try {
            app(ToggleUserActivation::class)->handle(auth()->user(), User::findOrFail($userId), $active);
        } catch (RuntimeException $exception) {
            Flux::toast(variant: 'danger', text: $exception->getMessage());

            return;
        }

        unset($this->users);
        Flux::toast(variant: 'success', text: $active ? 'فُتح الحساب.' : 'أُقفل الحساب.');
    }

    public function linkedRecordOf(User $user): ?string
    {
        return match (true) {
            $user->teacher !== null => 'أستاذ · '.$user->teacher->display_name,
            $user->guardian !== null => 'ولي أمر · '.$user->guardian->full_name,
            $user->student !== null => 'طالب · '.trim($user->student->first_name.' '.$user->student->family_name),
            default => null,
        };
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="المستخدمون" subheading="حسابات الدخول وأدوارها في المعاهد">
        <x-slot name="actions">
            <flux:button wire:click="invite" variant="primary" icon="plus" data-test="new-user">حساب جديد</flux:button>
        </x-slot>
    </x-page-header>

    <div class="flex flex-wrap items-end gap-4">
        <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بالاسم أو البريد" class="sm:max-w-xs" />

        <flux:select wire:model.live="role" placeholder="كل الأدوار" class="sm:max-w-40">
            <flux:select.option value="">كل الأدوار</flux:select.option>
            @foreach (\App\Enums\PanelRole::cases() as $panelRole)
                <flux:select.option value="{{ $panelRole->value }}">{{ $panelRole->label() }}</flux:select.option>
            @endforeach
        </flux:select>

        @if ($this->institutes->count() > 1)
            <flux:select wire:model.live="institute" class="sm:max-w-56">
                <flux:select.option value="">كل المعاهد</flux:select.option>
                @foreach ($this->institutes as $option)
                    <flux:select.option value="{{ $option->id }}">{{ $option->name }}</flux:select.option>
                @endforeach
            </flux:select>
        @endif
    </div>

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->users->isEmpty())
            <flux:text class="p-6 text-center">لا يوجد مستخدمون مطابقون.</flux:text>
        @else
            <flux:table :paginate="$this->users">
                <flux:table.columns>
                    <flux:table.column>المستخدم</flux:table.column>
                    <flux:table.column>اسم المستخدم</flux:table.column>
                    <flux:table.column>الأدوار</flux:table.column>
                    <flux:table.column>السجلّ المرتبط</flux:table.column>
                    <flux:table.column>الحالة</flux:table.column>
                    <flux:table.column></flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->users as $user)
                        <flux:table.row :key="$user->id">
                            <flux:table.cell>{{ $user->name }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $user->username ?? $user->email }}</flux:table.cell>
                            <flux:table.cell>
                                <div class="flex flex-wrap gap-1">
                                    @forelse ($this->assignments->get($user->id, []) as $assignment)
                                        <flux:badge
                                            size="sm"
                                            :color="$assignment['institute_id'] === \App\Models\User::GLOBAL_TEAM_ID ? 'amber' : 'zinc'"
                                            wire:key="role-{{ $user->id }}-{{ $assignment['role'] }}-{{ $assignment['institute_id'] }}"
                                        >
                                            {{ \App\Enums\PanelRole::labelOf($assignment['role']) }}
                                            @if ($assignment['institute'])
                                                <span class="opacity-70">· {{ $assignment['institute'] }}</span>
                                            @else
                                                <span class="opacity-70">· كل المعاهد</span>
                                            @endif
                                        </flux:badge>
                                    @empty
                                        <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">بلا دور</flux:text>
                                    @endforelse
                                </div>
                            </flux:table.cell>
                            <flux:table.cell>{{ $this->linkedRecordOf($user) ?? '—' }}</flux:table.cell>
                            <flux:table.cell>
                                <flux:badge size="sm" :color="$user->is_active ? 'lime' : 'zinc'">
                                    {{ $user->is_active ? 'نشط' : 'مقفل' }}
                                </flux:badge>
                            </flux:table.cell>
                            <flux:table.cell>
                                <flux:dropdown position="bottom" align="end">
                                    <flux:button icon="ellipsis-horizontal" size="sm" variant="subtle" />
                                    <flux:menu>
                                        <flux:menu.item wire:click="openRoleForm('{{ $user->id }}')" icon="identification">إسناد دور</flux:menu.item>

                                        @can('credentials.manage')
                                            <flux:menu.item wire:click="resetPassword({{ $user->id }})" icon="key" data-test="reset-password">توليد كلمة مرور</flux:menu.item>
                                        @endcan

                                        @if ($user->is_active)
                                            <flux:menu.item wire:click="toggleActivation({{ $user->id }}, false)" icon="lock-closed">إقفال الحساب</flux:menu.item>
                                        @else
                                            <flux:menu.item wire:click="toggleActivation({{ $user->id }}, true)" icon="lock-open">فتح الحساب</flux:menu.item>
                                        @endif

                                        @foreach ($this->assignments->get($user->id, []) as $assignment)
                                            <flux:menu.item
                                                wire:key="revoke-{{ $user->id }}-{{ $assignment['role'] }}-{{ $assignment['institute_id'] }}"
                                                wire:click="revoke({{ $user->id }}, '{{ $assignment['role'] }}', {{ $assignment['institute_id'] }})"
                                                icon="x-mark"
                                                variant="danger"
                                            >
                                                سحب «{{ \App\Enums\PanelRole::labelOf($assignment['role']) }}»
                                            </flux:menu.item>
                                        @endforeach
                                    </flux:menu>
                                </flux:dropdown>
                            </flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>

    <flux:modal name="invite-user" class="w-full max-w-lg">
        <form wire:submit="save" class="space-y-6">
            <flux:heading size="lg">حساب جديد</flux:heading>

            @if ($issuedCredentials)
                <flux:callout icon="key" variant="success">
                    <flux:callout.heading>أُنشئ الحساب</flux:callout.heading>
                    <flux:callout.text>
                        سلّم صاحبَ الحساب هذه البيانات — وتبقى متاحةً في شاشة «بيانات الدخول» لمن يعلوه رتبةً.
                    </flux:callout.text>

                    <div class="mt-3 grid gap-3 sm:grid-cols-2">
                        <flux:input readonly label="اسم المستخدم" :value="$issuedCredentials['username']" class="latin-numerals" data-test="issued-username" />
                        <flux:input readonly label="كلمة المرور" :value="$issuedCredentials['password']" class="latin-numerals" data-test="issued-password" />
                    </div>
                </flux:callout>

                <flux:modal.close><flux:button variant="primary">تمّ</flux:button></flux:modal.close>
            @else
                <div class="grid gap-6 sm:grid-cols-2">
                    <flux:input wire:model="first_name" label="الاسم" required />
                    <flux:input wire:model="last_name" label="الكنية" required />
                    <flux:input wire:model="email" type="email" label="البريد الإلكتروني" description="اختياري — يصلح بديلاً لاسم المستخدم عند الدخول" />
                    <flux:input wire:model="phone" label="الجوال" />
                </div>

                <flux:select wire:model.live="new_role" label="الدور" required>
                    <flux:select.option value="">اختر دوراً</flux:select.option>
                    @foreach ($this->creatableRoles as $panelRole)
                        <flux:select.option value="{{ $panelRole->value }}">{{ $panelRole->label() }}</flux:select.option>
                    @endforeach
                </flux:select>

                <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">
                    حسابات الأساتذة وأولياء الأمور والطلاب يولّدها النظام مع سجلّاتها، وتُدار من شاشة «بيانات الدخول».
                </flux:text>

                @unless (\App\Enums\PanelRole::tryFrom($new_role)?->isGlobal())
                    <flux:select wire:model="new_institute" label="المعهد" description="الدور يُسنَد داخل هذا المعهد وحده">
                        @foreach ($this->institutes as $option)
                            <flux:select.option value="{{ $option->id }}">{{ $option->name }}</flux:select.option>
                        @endforeach
                    </flux:select>
                @endunless

                <div class="flex gap-2">
                    <flux:button type="submit" variant="primary" data-test="save-user">إنشاء</flux:button>
                    <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                </div>
            @endunless
        </form>
    </flux:modal>

    <flux:modal name="issued-credentials" class="w-full max-w-md">
        <div class="space-y-6">
            <flux:heading size="lg">بيانات الدخول الجديدة</flux:heading>

            @if ($issuedCredentials)
                <div class="grid gap-3 sm:grid-cols-2">
                    <flux:input readonly label="اسم المستخدم" :value="$issuedCredentials['username']" class="latin-numerals" />
                    <flux:input readonly label="كلمة المرور" :value="$issuedCredentials['password']" class="latin-numerals" data-test="regenerated-password" />
                </div>
            @endif

            <flux:modal.close><flux:button variant="primary">تمّ</flux:button></flux:modal.close>
        </div>
    </flux:modal>

    <flux:modal name="assign-role" class="w-full max-w-md">
        <form wire:submit="assign" class="space-y-6">
            <flux:heading size="lg">إسناد دور</flux:heading>

            <flux:select wire:model.live="new_role" label="الدور" required>
                <flux:select.option value="">اختر دوراً</flux:select.option>
                @foreach ($this->assignableRoles as $panelRole)
                    <flux:select.option value="{{ $panelRole->value }}">{{ $panelRole->label() }}</flux:select.option>
                @endforeach
            </flux:select>

            @unless (\App\Enums\PanelRole::tryFrom($new_role)?->isGlobal())
                <flux:select wire:model="new_institute" label="المعهد">
                    @foreach ($this->institutes as $option)
                        <flux:select.option value="{{ $option->id }}">{{ $option->name }}</flux:select.option>
                    @endforeach
                </flux:select>
            @endunless

            <div class="flex gap-2">
                <flux:button type="submit" variant="primary" data-test="save-role">إسناد</flux:button>
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
            </div>
        </form>
    </flux:modal>
</div>
