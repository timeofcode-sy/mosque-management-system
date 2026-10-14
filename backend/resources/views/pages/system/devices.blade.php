<?php

use App\Models\SyncDevice;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * الأجهزة المزامِنة — أداة مبرمج (system.debug).
 *
 * جدول sync_devices يُكتب من RegisterDevice و SyncPull ولا واجهة له. الغرض هنا
 * تشخيصيّ أولاً: جهازٌ توقّف last_pulled_seq عنده منذ أيام هو جهازٌ عالق، وهذه
 * الشاشة أسرع طريق لرؤيته قبل أن يشتكي صاحبه.
 *
 * وإحصاءٌ ثانياً: التطبيقُ يرسل مع تسجيله نوعَ الجهاز وصانعَه وطرازَه ونسخةَ نظامه
 * ونسخةَ التطبيق — فيُعرف أيُّ نسخ أندرويد ما زالت تُحمل، وأيُّ الأجهزة لم يبلغها التحديث.
 */
new #[Title('الأجهزة المزامِنة')] class extends Component {
    use WithPagination;

    /** الجهازُ النشط: سحب أو سجّل خلال هذه المدّة. */
    public const ACTIVE_DAYS = 30;

    #[Url(as: 'q', except: '')]
    public string $search = '';

    #[Url(as: 'app', except: '')]
    public string $app = '';

    public function updatedSearch(): void
    {
        $this->resetPage();
    }

    public function updatedApp(): void
    {
        $this->resetPage();
        unset($this->stats);
    }

    /**
     * @return LengthAwarePaginator<int, SyncDevice>
     */
    #[Computed]
    public function devices(): LengthAwarePaginator
    {
        return SyncDevice::query()
            ->with('user:id,first_name,last_name,email')
            ->when($this->app !== '', fn ($query) => $query->where('app', $this->app))
            ->when($this->search !== '', fn ($query) => $query->where(fn ($inner) => $inner
                ->where('device_uuid', 'like', "%{$this->search}%")
                ->orWhere('platform', 'like', "%{$this->search}%")
                ->orWhere('manufacturer', 'like', "%{$this->search}%")
                ->orWhere('model', 'like', "%{$this->search}%")
                ->orWhereHas('user', fn ($user) => $user->where('email', 'like', "%{$this->search}%"))))
            ->orderByDesc('last_pulled_at')
            ->paginate(20);
    }

    /**
     * @return list<string>
     */
    #[Computed]
    public function apps(): array
    {
        return SyncDevice::query()->distinct()->orderBy('app')->pluck('app')->all();
    }

    /**
     * أعدادُ الأجهزة النشطة مجمَّعةً بخمسة أبعاد — الأكثرُ أولاً.
     *
     * @return array{total: int, active: int, described: int, groups: array<string, array{label: string, rows: Collection<int, array{label: string, count: int}>}>}
     */
    #[Computed]
    public function stats(): array
    {
        $since = now()->subDays(self::ACTIVE_DAYS);

        $base = SyncDevice::query()->when($this->app !== '', fn ($query) => $query->where('app', $this->app));

        $active = (clone $base)->where(fn ($query) => $query
            ->where('last_pulled_at', '>=', $since)
            ->orWhere('updated_at', '>=', $since))
            ->get(['device_type', 'manufacturer', 'os_version', 'app_version', 'app_build', 'app', 'platform', 'screen']);

        $group = fn (callable $key, int $limit = 6) => $active
            ->groupBy(fn (SyncDevice $device) => $key($device) ?: 'غير معروف')
            ->map(fn (Collection $devices, string $label) => ['label' => $label, 'count' => $devices->count()])
            ->sortByDesc('count')
            ->take($limit)
            ->values();

        $types = ['phone' => 'هاتف', 'tablet' => 'لوحي', 'desktop' => 'حاسوب'];

        return [
            'total' => (clone $base)->count(),
            'active' => $active->count(),
            // الحاسوبُ بلا صانع، فالموصوفُ ما عُرف صانعُه أو نظامُه.
            'described' => $active->filter(fn (SyncDevice $device) => $device->manufacturer !== null || $device->os_version !== null)->count(),
            'groups' => [
                'type' => ['label' => 'نوع الجهاز', 'rows' => $group(fn ($device) => $types[$device->device_type] ?? null)],
                'manufacturer' => ['label' => 'الشركة المصنّعة', 'rows' => $group(fn ($device) => $device->manufacturer ? Str::title($device->manufacturer) : null)],
                'os' => ['label' => 'نسخة النظام', 'rows' => $group(fn ($device) => $device->os_version)],
                'version' => ['label' => 'نسخة التطبيق', 'rows' => $group(fn ($device) => $device->app_version)],
                'app' => ['label' => 'التطبيق', 'rows' => $group(fn ($device) => $device->app)],
                'screen' => ['label' => 'مقاس الشاشة', 'rows' => $group(fn ($device) => $device->screen)],
            ],
        ];
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الأجهزة المزامِنة" subheading="آخر سحب ودفع لكل جهاز، وإحصاءُ الأجهزة النشطة خلال {{ $this::ACTIVE_DAYS }} يوماً" />

    <div class="flex flex-col gap-3 sm:flex-row">
        <flux:input wire:model.live.debounce.300ms="search" icon="magnifying-glass" placeholder="ابحث بمعرّف الجهاز أو طرازه أو بريد المستخدم" class="sm:max-w-md" />
        <flux:select wire:model.live="app" class="sm:max-w-48" data-test="app-filter">
            <flux:select.option value="">كل التطبيقات</flux:select.option>
            @foreach ($this->apps as $appName)
                <flux:select.option value="{{ $appName }}">{{ $appName }}</flux:select.option>
            @endforeach
        </flux:select>
    </div>

    @php($stats = $this->stats)

    <div class="grid gap-4 sm:grid-cols-3">
        <div class="rounded-xl border border-line bg-raised p-4">
            <flux:text size="sm" class="text-muted">كل الأجهزة المسجَّلة</flux:text>
            <p class="latin-numerals font-display text-2xl font-semibold text-primary">{{ $stats['total'] }}</p>
        </div>
        <div class="rounded-xl border border-line bg-raised p-4">
            <flux:text size="sm" class="text-muted">النشطة خلال {{ $this::ACTIVE_DAYS }} يوماً</flux:text>
            <p class="latin-numerals font-display text-2xl font-semibold text-primary" data-test="active-devices">{{ $stats['active'] }}</p>
        </div>
        <div class="rounded-xl border border-line bg-raised p-4">
            <flux:text size="sm" class="text-muted">النشطة الموصوفة</flux:text>
            <p class="latin-numerals font-display text-2xl font-semibold text-primary">{{ $stats['described'] }}</p>
            <flux:text size="sm" class="text-muted">الوصفُ يصل من الإصدار 1.0.0-beta.7 فما بعده</flux:text>
        </div>
    </div>

    @if ($stats['active'] > 0)
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            @foreach ($stats['groups'] as $key => $group)
                <section class="rounded-xl border border-line bg-raised p-4" data-test="stats-{{ $key }}">
                    <h2 class="mb-3 font-semibold text-ink">{{ $group['label'] }}</h2>
                    <ul class="flex flex-col gap-2">
                        @foreach ($group['rows'] as $row)
                            @php($share = (int) round($row['count'] * 100 / $stats['active']))
                            <li class="flex flex-col gap-1">
                                <div class="flex items-baseline justify-between gap-2 text-sm">
                                    <span class="truncate latin-numerals" dir="auto">{{ $row['label'] }}</span>
                                    <span class="latin-numerals shrink-0 text-muted">{{ $row['count'] }} · {{ $share }}%</span>
                                </div>
                                <div class="h-1.5 overflow-hidden rounded-full bg-line">
                                    <div class="h-full rounded-full bg-primary" style="width: {{ max($share, 2) }}%"></div>
                                </div>
                            </li>
                        @endforeach
                    </ul>
                </section>
            @endforeach
        </div>
    @endif

    <div class="rounded-xl border border-line bg-raised">
        @if ($this->devices->isEmpty())
            <flux:text class="p-6 text-center">لا توجد أجهزة مسجَّلة بعد.</flux:text>
        @else
            <flux:table :paginate="$this->devices">
                <flux:table.columns>
                    <flux:table.column>الجهاز</flux:table.column>
                    <flux:table.column>المستخدم</flux:table.column>
                    <flux:table.column>التطبيق</flux:table.column>
                    <flux:table.column>الطراز</flux:table.column>
                    <flux:table.column>النظام</flux:table.column>
                    <flux:table.column>آخر تسلسل مسحوب</flux:table.column>
                    <flux:table.column>آخر سحب</flux:table.column>
                    <flux:table.column>آخر دفع</flux:table.column>
                </flux:table.columns>

                <flux:table.rows>
                    @foreach ($this->devices as $device)
                        <flux:table.row :key="$device->id">
                            <flux:table.cell class="latin-numerals text-xs">{{ Str::limit($device->device_uuid, 13) }}</flux:table.cell>
                            <flux:table.cell>{{ $device->user?->name ?? '—' }}</flux:table.cell>
                            <flux:table.cell class="latin-numerals">
                                {{ $device->app }}
                                <span class="block text-xs text-muted" dir="ltr">{{ $device->app_version }}{{ $device->app_build ? ' ('.$device->app_build.')' : '' }}</span>
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals" dir="auto">
                                {{ trim(Str::title((string) $device->manufacturer).' '.$device->model) ?: '—' }}
                                @if ($device->device_type || $device->screen)
                                    <span class="block text-xs text-muted">{{ ['phone' => 'هاتف', 'tablet' => 'لوحي', 'desktop' => 'حاسوب'][$device->device_type] ?? '' }} {{ $device->screen }}</span>
                                @endif
                            </flux:table.cell>
                            <flux:table.cell class="latin-numerals" dir="auto">{{ $device->os_version ?: ($device->platform ?: '—') }}</flux:table.cell>
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
