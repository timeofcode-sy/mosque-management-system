<?php

use App\Models\SyncDevice;
use Illuminate\Pagination\LengthAwarePaginator;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * الأجهزة المزامِنة — أداة مبرمج (system.debug).
 *
 * جدول sync_devices يُكتب من RegisterDevice و SyncPull ولا واجهة له. الغرض هنا
 * تشخيصيّ بحت: جهازٌ توقّف last_pulled_seq عنده منذ أيام هو جهازٌ عالق، وهذه
 * الشاشة أسرع طريق لرؤيته قبل أن يشتكي صاحبه.
 */
new #[Title('الأجهزة المزامِنة')] class extends Component {
    use WithPagination;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    /**
     * @return LengthAwarePaginator<int, SyncDevice>
     */
    #[Computed]
    public function devices(): LengthAwarePaginator
    {
        return SyncDevice::query()
            ->with('user:id,first_name,last_name,email')
            ->when($this->search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('device_uuid', 'like', "%{$this->search}%")
                ->orWhere('platform', 'like', "%{$this->search}%")
                ->orWhereHas('user', fn ($user) => $user->where('email', 'like', "%{$this->search}%"))))
            ->orderByDesc('last_pulled_at')
            ->paginate(20);
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الأجهزة المزامِنة" subheading="آخر سحب ودفع لكل جهاز — لتشخيص الأجهزة العالقة" />

    <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بمعرّف الجهاز أو بريد المستخدم" class="sm:max-w-md" />

    <div class="rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
        @if ($this->devices->isEmpty())
            <flux:text class="p-6 text-center">لا توجد أجهزة مسجَّلة بعد.</flux:text>
        @else
            <flux:table :paginate="$this->devices">
                <flux:table.columns>
                    <flux:table.column>الجهاز</flux:table.column>
                    <flux:table.column>المستخدم</flux:table.column>
                    <flux:table.column>التطبيق</flux:table.column>
                    <flux:table.column>المنصّة</flux:table.column>
                    <flux:table.column>آخر تسلسل مسحوب</flux:table.column>
                    <flux:table.column>آخر سحب</flux:table.column>
                    <flux:table.column>آخر دفع</flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->devices as $device)
                        <flux:table.row :key="$device->id">
                            <flux:table.cell class="latin-numerals text-xs">{{ Str::limit($device->device_uuid, 13) }}</flux:table.cell>
                            <flux:table.cell>{{ $device->user?->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $device->app }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $device->platform ?: '—' }} {{ $device->app_version }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $device->last_pulled_seq }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $device->last_pulled_at?->format('Y-m-d H:i') ?? '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">{{ $device->last_pushed_at?->format('Y-m-d H:i') ?? '—' }}</flux:table.cell>
                        </flux:table.row>
                    @endforeach
                </flux:table.rows>
            </flux:table>
        @endif
    </div>
</div>
