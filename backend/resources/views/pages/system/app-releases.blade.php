<?php

use App\Actions\SaveAppRelease;
use App\Enums\AppTarget;
use App\Models\AppRelease;
use App\Queries\AppUpdateQuery;
use Flux\Flux;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Validation\Rule;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\Features\SupportFileUploads\TemporaryUploadedFile;
use Livewire\WithFileUploads;

/**
 * تحديثاتُ التطبيقات — أداة مبرمج (system.debug).
 *
 * ما يُنشر هنا يسأل عنه كلُّ تطبيقٍ عند فتحه (`GET /app-updates/check`)، فيعرض على صاحبه
 * الإصدارَ وسجلَّ تغييراته، وينزّله ويثبّته من داخله. والإصدارُ الإلزاميّ يحجب التطبيقَ حتى يُحدَّث.
 *
 * وبطاقاتُ الأهداف في رأس الشاشة تجيب السؤالَ الذي وُجدت الميزةُ له: كم جهازاً بلغه الإصدار
 * الأخير، وكم بقي خلفه، وعلى أيّ بناء.
 */
new #[Title('تحديثات التطبيقات')] class extends Component {
    use WithFileUploads;

    #[Url(as: 'target', except: '')]
    public string $filterTarget = '';

    public ?string $editingUuid = null;

    public string $target = 'mobile';

    public string $version = '';

    public ?int $buildNumber = null;

    public string $title = '';

    public string $notes = '';

    public bool $isMandatory = false;

    /** مصدرُ الملف: مرفوعٌ إلى هذا الخادم، أو رابطٌ خارجي. */
    public string $source = 'file';

    public string $externalUrl = '';

    /** @var TemporaryUploadedFile|null */
    public $package = null;

    public bool $publishNow = true;

    public ?string $deletingUuid = null;

    /**
     * @return array<string, array{latest: ?AppRelease, active: int, upToDate: int, builds: array<int, array{build: int, version: ?string, devices: int}>}>
     */
    #[Computed]
    public function overview(): array
    {
        return app(AppUpdateQuery::class)->overview();
    }

    /**
     * @return Collection<int, AppRelease>
     */
    #[Computed]
    public function releases(): Collection
    {
        return AppRelease::query()
            ->with('createdBy:id,first_name,last_name')
            ->when(AppTarget::tryFrom($this->filterTarget), fn ($query, AppTarget $target) => $query->forTarget($target))
            ->orderByDesc('build_number')
            ->orderBy('target')
            ->get();
    }

    #[Computed]
    public function editing(): ?AppRelease
    {
        return $this->editingUuid === null ? null : AppRelease::query()->where('uuid', $this->editingUuid)->first();
    }

    /**
     * أصغرُ السقفين في PHP — ما يتجاوزه يُرفض قبل أن يبلغ Livewire، فيُقال للمبرمج مسبقاً.
     */
    #[Computed]
    public function uploadLimit(): string
    {
        $bytes = min($this->iniBytes('upload_max_filesize'), $this->iniBytes('post_max_size'), 300 * 1024 * 1024);

        return number_format($bytes / 1024 / 1024).' MB';
    }

    public function create(?string $target = null): void
    {
        $this->reset('editingUuid', 'version', 'buildNumber', 'title', 'notes', 'isMandatory', 'source', 'externalUrl', 'package', 'publishNow');
        $this->target = AppTarget::tryFrom((string) $target)?->value ?? ($this->filterTarget ?: AppTarget::Mobile->value);

        // الإصدارُ التالي يُقترح من الأخير: رقمُ البناء يزيد واحداً، والمبرمج يصحّحه إن شاء.
        $last = AppRelease::query()->forTarget(AppTarget::from($this->target))->orderByDesc('build_number')->first();
        $this->buildNumber = $last === null ? null : $last->build_number + 1;

        $this->resetValidation();
        Flux::modal('release-form')->show();
    }

    public function edit(string $uuid): void
    {
        $release = AppRelease::query()->where('uuid', $uuid)->firstOrFail();

        $this->editingUuid = $release->uuid;
        $this->target = $release->target->value;
        $this->version = $release->version;
        $this->buildNumber = $release->build_number;
        $this->title = (string) $release->title;
        $this->notes = (string) $release->notes;
        $this->isMandatory = $release->is_mandatory;
        $this->source = $release->hasFile() || blank($release->external_url) ? 'file' : 'url';
        $this->externalUrl = (string) $release->external_url;
        $this->package = null;
        $this->publishNow = $release->published_at !== null;

        $this->resetValidation();
        Flux::modal('release-form')->show();
    }

    /**
     * ملفٌّ خرج من `scripts/export-apps.ps1` يحمل في اسمه ما تحتاجه الاستمارة —
     * `nuzuln-admin-android-1.0.0-beta.6-b6.apk` — فتُملأ منه ولا تُكتب باليد.
     */
    public function updatedPackage(): void
    {
        $name = $this->package?->getClientOriginalName() ?? '';

        if (! preg_match('/^nuzuln-([a-z-]+?)-(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)-b(\d+)(?:-windows)?\.(apk|zip)$/i', $name, $match)) {
            return;
        }

        if ($target = AppTarget::tryFrom(str_replace('-', '_', strtolower($match[1])))) {
            $this->target = $target->value;
        }

        $this->version = $match[2];
        $this->buildNumber = (int) $match[3];
    }

    public function save(): void
    {
        $existing = $this->editing;
        $target = AppTarget::tryFrom($this->target) ?? AppTarget::Mobile;
        $needsFile = $this->source === 'file' && ! ($existing?->hasFile() ?? false);

        $validated = $this->validate([
            'target' => ['required', Rule::enum(AppTarget::class)],
            'version' => ['required', 'string', 'max:32', 'regex:/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?$/'],
            'buildNumber' => [
                'required', 'integer', 'min:1', 'max:2000000000',
                Rule::unique('app_releases', 'build_number')
                    ->where('target', $this->target)
                    ->ignore($existing?->id),
            ],
            'title' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'isMandatory' => ['boolean'],
            'source' => ['required', 'in:file,url'],
            'package' => [$needsFile ? 'required' : 'nullable', 'file', 'max:307200', 'extensions:'.$target->extension()],
            'externalUrl' => ['required_if:source,url', 'nullable', 'url:https,http', 'max:2048'],
        ], [
            'version.regex' => 'اكتب الإصدار بصيغة 1.2.0 أو 1.2.0-beta.3.',
            'buildNumber.unique' => 'لهذا التطبيق إصدارٌ بهذا الرقم من قبل — رقمُ البناء يزيد مع كل نسخة.',
            'package.extensions' => 'ملفُّ '.$target->label().' امتدادُه .'.$target->extension().'.',
        ], [
            'target' => 'التطبيق',
            'version' => 'الإصدار',
            'buildNumber' => 'رقم البناء',
            'title' => 'العنوان',
            'notes' => 'سجل التغييرات',
            'package' => 'الملف',
            'externalUrl' => 'رابط التنزيل',
        ]);

        app(SaveAppRelease::class)->handle(
            [
                'target' => $validated['target'],
                'version' => $validated['version'],
                'build_number' => $validated['buildNumber'],
                'title' => $validated['title'],
                'notes' => $validated['notes'],
                'is_mandatory' => $this->isMandatory,
                'external_url' => $this->source === 'url' ? $validated['externalUrl'] : null,
                // التعديلُ لا يغيّر تاريخ النشر الأول: هو ما تُرتَّب به سجلّاتُ التغيير على الأجهزة.
                'published_at' => $this->publishNow ? ($existing?->published_at ?? now()) : null,
            ],
            $this->source === 'file' ? $this->package : null,
            auth()->user(),
            $existing,
        );

        $this->package = null;
        unset($this->releases, $this->overview, $this->editing);

        Flux::modal('release-form')->close();
        Flux::toast(
            variant: 'success',
            text: $this->publishNow
                ? ($this->isMandatory ? 'نُشر الإصدار إلزامياً: لن تعمل النسخ الأقدم حتى تُحدَّث.' : 'نُشر الإصدار ويُعرض على الأجهزة عند فتح التطبيق.')
                : 'حُفظ الإصدار مسودّةً ولا يصل أحداً.',
        );
    }

    public function togglePublished(string $uuid): void
    {
        $release = AppRelease::query()->where('uuid', $uuid)->firstOrFail();
        $release->update(['published_at' => $release->published_at === null ? now() : null]);

        unset($this->releases, $this->overview);

        Flux::toast(
            variant: $release->published_at === null ? 'warning' : 'success',
            text: $release->published_at === null ? 'سُحب الإصدار ولم يعد يُعرض على الأجهزة.' : 'نُشر الإصدار.',
        );
    }

    public function confirmDelete(string $uuid): void
    {
        $this->deletingUuid = $uuid;
        Flux::modal('release-delete')->show();
    }

    public function delete(): void
    {
        $release = AppRelease::query()->where('uuid', (string) $this->deletingUuid)->first();

        if ($release !== null) {
            app(SaveAppRelease::class)->delete($release);
        }

        $this->deletingUuid = null;
        unset($this->releases, $this->overview);

        Flux::modal('release-delete')->close();
        Flux::toast(variant: 'warning', text: 'حُذف الإصدار وملفُّه.');
    }

    private function iniBytes(string $key): int
    {
        $value = trim((string) ini_get($key));

        if ($value === '' || $value === '-1' || $value === '0') {
            return PHP_INT_MAX;
        }

        $number = (int) $value;

        return match (strtolower(substr($value, -1))) {
            'g' => $number * 1024 ** 3,
            'm' => $number * 1024 ** 2,
            'k' => $number * 1024,
            default => $number,
        };
    }
}; ?>

@php
    /** حجمٌ يقرؤه الإنسان، بأرقامٍ لاتينية. */
    $size = fn (?int $bytes): string => $bytes === null ? '—' : ($bytes >= 1048576 ? number_format($bytes / 1048576, 1).' MB' : number_format($bytes / 1024).' KB');
@endphp

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="تحديثات التطبيقات" subheading="ما يصل أجهزةَ المستخدمين من إصدارات، وما يُفرض منها">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-release">إصدار جديد</flux:button>
        </x-slot>
    </x-page-header>

    {{-- بطاقةٌ لكل هدف: الإصدارُ الأخير، ومن بلغه من الأجهزة النشطة. --}}
    <div class="grid gap-4 lg:grid-cols-3">
        @foreach (AppTarget::cases() as $appTarget)
            @php
                $card = $this->overview[$appTarget->value];
                $latest = $card['latest'];
                $share = $card['active'] > 0 ? (int) round($card['upToDate'] * 100 / $card['active']) : null;
                $filled = $share === null ? 0 : (int) round($share * 30 / 100);
            @endphp

            <section class="flex flex-col overflow-hidden rounded-xl border border-line bg-raised" data-test="target-{{ $appTarget->value }}" aria-labelledby="target-{{ $appTarget->value }}-title">
                <header class="nz-pattern-night flex items-center gap-3 px-4 py-3 text-star">
                    <span class="grid size-10 shrink-0 place-items-center bg-night-raised text-bronze [clip-path:polygon(50%_0,100%_21%,100%_79%,50%_100%,0_79%,0_21%)]">
                        <flux:icon :name="$appTarget->icon()" class="size-5" />
                    </span>
                    <div class="min-w-0">
                        <h2 id="target-{{ $appTarget->value }}-title" class="truncate font-semibold">{{ $appTarget->label() }}</h2>
                        <p class="truncate text-xs text-bronze">{{ $appTarget->audience() }}</p>
                    </div>
                </header>

                <div class="flex flex-1 flex-col gap-4 p-4">
                    @if ($latest === null)
                        <div class="flex flex-1 flex-col items-start gap-2">
                            <flux:text>لم يُنشر له إصدارٌ بعد — الأجهزةُ لا ترى تحديثاً.</flux:text>
                        </div>
                    @else
                        <div class="flex items-start justify-between gap-3">
                            <div>
                                <flux:text size="sm" class="text-muted">الإصدار الأخير</flux:text>
                                <p class="latin-numerals font-display text-2xl font-semibold text-primary" dir="ltr">{{ $latest->version }}</p>
                                <flux:text size="sm" class="latin-numerals text-muted">بناء {{ $latest->build_number }} · {{ $latest->published_at?->format('Y-m-d') }}</flux:text>
                            </div>
                            @if ($latest->is_mandatory)
                                <flux:badge color="amber" size="sm" icon="lock-closed">إلزامي</flux:badge>
                            @else
                                <flux:badge color="zinc" size="sm">اختياري</flux:badge>
                            @endif
                        </div>
                    @endif

                    <div class="flex flex-col gap-2">
                        <div class="flex items-baseline justify-between gap-2 text-sm">
                            <span class="font-semibold text-ink">
                                @if ($card['active'] === 0)
                                    لا أجهزة نشطة بعد
                                @else
                                    <span class="latin-numerals">{{ $card['upToDate'] }}</span> من <span class="latin-numerals">{{ $card['active'] }}</span> على الأخير
                                @endif
                            </span>
                            @if ($share !== null)
                                <span class="latin-numerals text-muted">{{ $share }}%</span>
                            @endif
                        </div>

                        {{-- ثلاثون خطّاً بزاوية الشعار كشريط الأجزاء: ما بلغ الأخيرَ من الأجهزة. --}}
                        <div class="nz-juz nz-juz--sm">
                            <div class="nz-juz__bar" role="img" aria-label="{{ $share === null ? 'لا أجهزة نشطة' : "{$share}% من الأجهزة النشطة على الإصدار الأخير" }}">
                                @for ($segment = 1; $segment <= 30; $segment++)
                                    <span class="nz-juz__seg {{ $segment <= $filled ? 'nz-juz__seg--done' : '' }}"></span>
                                @endfor
                            </div>
                        </div>

                        @if ($card['builds'] !== [])
                            <div class="flex flex-wrap gap-1.5">
                                @foreach (array_slice($card['builds'], 0, 6) as $row)
                                    @php $current = $latest !== null && $row['build'] >= $latest->build_number; @endphp
                                    <span @class([
                                        'latin-numerals inline-flex items-center gap-1 rounded-sm px-2 py-0.5 text-xs',
                                        'bg-success-soft text-success' => $current,
                                        'bg-sunken text-muted' => ! $current,
                                    ]) title="{{ $row['version'] }}">
                                        b{{ $row['build'] }} · {{ $row['devices'] }}
                                    </span>
                                @endforeach
                            </div>
                        @endif
                    </div>

                    <div class="mt-auto flex items-center justify-between gap-2 border-t border-line pt-3">
                        <flux:text size="sm" class="text-muted">
                            @if ($latest !== null)
                                <span class="latin-numerals">{{ number_format($latest->downloads) }}</span> تنزيل
                            @else
                                النشطة: آخر {{ AppUpdateQuery::ACTIVE_DAYS }} يوماً
                            @endif
                        </flux:text>
                        <flux:button wire:click="create('{{ $appTarget->value }}')" size="sm" variant="ghost" icon="plus">إصدار</flux:button>
                    </div>
                </div>
            </section>
        @endforeach
    </div>

    <div class="flex flex-wrap items-center justify-between gap-3">
        <flux:heading size="lg" level="2">سجل الإصدارات</flux:heading>

        <flux:radio.group wire:model.live="filterTarget" variant="segmented" size="sm" aria-label="تصفية بالتطبيق">
            <flux:radio value="" label="الكل" />
            @foreach (AppTarget::cases() as $appTarget)
                <flux:radio :value="$appTarget->value" :label="$appTarget->label()" />
            @endforeach
        </flux:radio.group>
    </div>

    @if ($this->releases->isEmpty())
        <div class="nz-pattern-soft flex flex-col items-center gap-3 rounded-xl border border-line p-10 text-center">
            <flux:icon name="arrow-down-tray" class="size-8 text-bronze-ink" />
            <flux:text>لا إصداراتٍ بعد. ارفع ملفَّ التطبيق كما خرج من سكربت التصدير، فتُملأ الاستمارةُ من اسمه.</flux:text>
            <flux:button wire:click="create" variant="primary" icon="plus" size="sm">إصدار جديد</flux:button>
        </div>
    @else
        <ol class="flex flex-col gap-3">
            @foreach ($this->releases as $release)
                <li wire:key="release-{{ $release->uuid }}" class="rounded-xl border border-line bg-raised" data-test="release-row">
                    <div class="flex flex-wrap items-start gap-4 p-4">
                        <div class="flex min-w-0 flex-1 flex-col gap-2">
                            <div class="flex flex-wrap items-center gap-2">
                                <span class="latin-numerals font-display text-lg font-semibold text-ink" dir="ltr">{{ $release->version }}</span>
                                <span class="latin-numerals text-sm text-muted">بناء {{ $release->build_number }}</span>
                                <span class="nz-tag">{{ $release->target->label() }}</span>

                                @if ($release->published_at === null)
                                    <flux:badge color="zinc" size="sm">مسودّة</flux:badge>
                                @else
                                    <flux:badge color="green" size="sm">منشور</flux:badge>
                                @endif

                                @if ($release->is_mandatory)
                                    <flux:badge color="amber" size="sm" icon="lock-closed">إلزامي</flux:badge>
                                @endif
                            </div>

                            @if ($release->title)
                                <p class="font-semibold text-ink">{{ $release->title }}</p>
                            @endif

                            @if ($release->noteLines() !== [])
                                <ul class="flex flex-col gap-1 text-sm text-ink">
                                    @foreach ($release->noteLines() as $line)
                                        <li class="flex gap-2">
                                            <span class="mt-2 size-1.5 shrink-0 rotate-45 bg-bronze-ink" aria-hidden="true"></span>
                                            <span>{{ $line }}</span>
                                        </li>
                                    @endforeach
                                </ul>
                            @endif

                            <div class="latin-numerals flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted">
                                @if ($release->hasFile())
                                    <span class="inline-flex items-center gap-1"><flux:icon name="document-arrow-down" class="size-4" />{{ $release->file_name }} · {{ $size($release->file_size) }}</span>
                                    <span class="inline-flex items-center gap-1" title="{{ $release->sha256 }}"><flux:icon name="finger-print" class="size-4" />SHA-256 {{ Str::limit((string) $release->sha256, 12, '…') }}</span>
                                @elseif ($release->external_url)
                                    <a href="{{ $release->external_url }}" target="_blank" rel="noopener" class="inline-flex items-center gap-1 underline decoration-dotted underline-offset-4" dir="ltr">
                                        <flux:icon name="link" class="size-4" />{{ Str::limit($release->external_url, 60) }}
                                    </a>
                                @else
                                    <span class="inline-flex items-center gap-1 text-danger"><flux:icon name="exclamation-triangle" class="size-4" />بلا ملفّ</span>
                                @endif
                                <span>{{ number_format($release->downloads) }} تنزيل</span>
                                @if ($release->published_at)
                                    <span>نُشر {{ $release->published_at->format('Y-m-d H:i') }}</span>
                                @endif
                                @if ($release->createdBy)
                                    <span>{{ $release->createdBy->name }}</span>
                                @endif
                            </div>
                        </div>

                        <div class="flex shrink-0 items-center gap-1">
                            <flux:button wire:click="edit('{{ $release->uuid }}')" size="sm" variant="ghost" icon="pencil" data-test="edit-release">تعديل</flux:button>
                            <flux:dropdown position="bottom" align="end">
                                <flux:button size="sm" variant="ghost" icon="ellipsis-vertical" aria-label="المزيد" />
                                <flux:menu>
                                    <flux:menu.item wire:click="togglePublished('{{ $release->uuid }}')" :icon="$release->published_at === null ? 'eye' : 'eye-slash'">
                                        {{ $release->published_at === null ? 'نشر' : 'سحب النشر' }}
                                    </flux:menu.item>
                                    <flux:menu.separator />
                                    <flux:menu.item wire:click="confirmDelete('{{ $release->uuid }}')" icon="trash" variant="danger">حذف</flux:menu.item>
                                </flux:menu>
                            </flux:dropdown>
                        </div>
                    </div>
                </li>
            @endforeach
        </ol>
    @endif

    <flux:modal name="release-form" class="w-full max-w-2xl">
        <form wire:submit="save" class="flex flex-col gap-5">
            <div>
                <flux:heading size="lg">{{ $editingUuid ? 'تعديل إصدار' : 'إصدار جديد' }}</flux:heading>
                <flux:text class="mt-1">رقمُ البناء وحده ما يُقارن به التطبيق: كلُّ جهازٍ رقمُه أصغر يُعرض عليه هذا الإصدار.</flux:text>
            </div>

            <flux:radio.group wire:model.live="target" label="التطبيق" variant="segmented" data-test="release-target">
                @foreach (AppTarget::cases() as $appTarget)
                    <flux:radio :value="$appTarget->value" :label="$appTarget->label()" />
                @endforeach
            </flux:radio.group>

            <div class="grid gap-4 sm:grid-cols-2">
                <flux:input wire:model="version" label="الإصدار" placeholder="1.0.0-beta.6" dir="ltr" class="latin-numerals" data-test="release-version" />
                <flux:input wire:model="buildNumber" type="number" min="1" label="رقم البناء" placeholder="6" dir="ltr" class="latin-numerals" data-test="release-build" />
            </div>

            <flux:input wire:model="title" label="العنوان (اختياري)" placeholder="مثلاً: التفقّد أسرع، وملف الطالب أوفى" />

            <flux:textarea wire:model="notes" label="سجل التغييرات" rows="6" placeholder="بندٌ في كل سطر" description="كلُّ سطرٍ بندٌ يراه المستخدم في شاشة التحديث." data-test="release-notes" />

            <div class="flex flex-col gap-3">
                <flux:radio.group wire:model.live="source" label="الملف" variant="segmented">
                    <flux:radio value="file" label="رفعه إلى الخادم" icon="arrow-up-tray" />
                    <flux:radio value="url" label="رابط خارجي" icon="link" />
                </flux:radio.group>

                @if ($source === 'file')
                    @php $currentTarget = AppTarget::tryFrom($target) ?? AppTarget::Mobile; @endphp
                    <div
                        x-data="{ uploading: false, progress: 0 }"
                        x-on:livewire-upload-start="uploading = true; progress = 0"
                        x-on:livewire-upload-finish="uploading = false"
                        x-on:livewire-upload-cancel="uploading = false"
                        x-on:livewire-upload-error="uploading = false"
                        x-on:livewire-upload-progress="progress = $event.detail.progress"
                        class="flex flex-col gap-3 rounded-lg border border-dashed border-line bg-surface p-4"
                    >
                        <div class="flex flex-wrap items-center gap-3">
                            <label for="release-package" class="inline-flex cursor-pointer items-center gap-2 rounded-sm border border-line bg-raised px-3 py-1.5 text-sm font-medium text-ink transition hover:bg-sunken">
                                <flux:icon name="arrow-up-tray" class="size-4" />
                                اختر ملفّ .{{ $currentTarget->extension() }}
                            </label>
                            <input id="release-package" type="file" wire:model="package" accept=".{{ $currentTarget->extension() }}" class="sr-only" data-test="release-package" />

                            <flux:text size="sm" class="latin-numerals">
                                @if ($package)
                                    {{ $package->getClientOriginalName() }} · {{ $size($package->getSize()) }}
                                @elseif ($this->editing?->hasFile())
                                    الحالي: {{ $this->editing->file_name }} · {{ $size($this->editing->file_size) }}
                                @else
                                    الحدّ الأقصى على هذا الخادم: {{ $this->uploadLimit }}
                                @endif
                            </flux:text>
                        </div>

                        <div x-show="uploading" x-cloak class="nz-juz nz-juz--sm">
                            <div class="nz-juz__label"><b>جارٍ الرفع</b><span class="latin-numerals" x-text="progress + '%'"></span></div>
                            <div class="nz-juz__bar" aria-hidden="true">
                                @for ($segment = 1; $segment <= 30; $segment++)
                                    <span class="nz-juz__seg" x-bind:class="{ 'nz-juz__seg--done': progress >= {{ round($segment * 100 / 30, 1) }} }"></span>
                                @endfor
                            </div>
                        </div>

                        <flux:text size="sm" class="text-muted">
                            ارفع الملفَّ كما أخرجه سكربت التصدير (مثل <span class="latin-numerals" dir="ltr">nuzuln-mobile-1.0.0-beta.6-b6.apk</span>) فيُقرأ منه التطبيقُ والإصدارُ ورقمُ البناء.
                            يُحسب حجمُه وبصمتُه هنا، ويتحقّق التطبيق منهما قبل التثبيت.
                        </flux:text>
                        <flux:error name="package" />
                    </div>
                @else
                    <flux:input wire:model="externalUrl" type="url" placeholder="https://…" dir="ltr" description="رابطٌ مباشر إلى الملف نفسِه، لا إلى صفحةٍ فيها زرّ تنزيل." data-test="release-url" />
                @endif
            </div>

            <div class="flex flex-col gap-3 rounded-lg border border-line p-4">
                <flux:switch wire:model.live="isMandatory" label="تحديث إلزامي" description="لا يعمل التطبيق على نسخةٍ أقدم حتى يُحدَّث. للإصلاحات التي لا يصحّ أن يبقى أحدٌ دونها." data-test="release-mandatory" />
                <flux:separator variant="subtle" />
                <flux:switch wire:model="publishNow" label="انشره الآن" description="المسودّة تُحفظ ولا تُعرض على أيّ جهاز." />
            </div>

            @if ($isMandatory)
                <flux:callout variant="warning" icon="exclamation-triangle" heading="الإلزامُ يسري على كل نسخةٍ أقدم">
                    <flux:callout.text>ومن فاته هذا الإصدار يُعرض عليه كلُّ ما بعده إلزامياً أيضاً، ولو نُشر اختيارياً.</flux:callout.text>
                </flux:callout>
            @endif

            <div class="flex justify-end gap-2">
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                <flux:button type="submit" variant="primary" data-test="save-release" wire:loading.attr="disabled" wire:target="save,package">حفظ</flux:button>
            </div>
        </form>
    </flux:modal>

    <flux:modal name="release-delete" class="w-full max-w-md">
        <div class="flex flex-col gap-4">
            <flux:heading size="lg">حذف الإصدار؟</flux:heading>
            <flux:text>يُحذف الإصدارُ وملفُّه من الخادم، ولا يُعرض بعدها على أيّ جهاز. ما ثُبّت منه على الأجهزة يبقى كما هو.</flux:text>
            <div class="flex justify-end gap-2">
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                <flux:button wire:click="delete" variant="danger" data-test="confirm-delete-release">حذف</flux:button>
            </div>
        </div>
    </flux:modal>
</div>
