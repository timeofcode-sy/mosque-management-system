<?php

use App\Actions\PublishAnnouncement;
use App\Concerns\InteractsWithInstitute;
use App\Models\Announcement;
use App\Models\CourseCircle;
use App\Queries\AnnouncementQuery;
use Flux\Flux;
use Illuminate\Support\Collection;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Title;
use Livewire\Component;

/**
 * إعلاناتُ المعهد — ✅ م.8.1، **وهي الطرفُ الكاتب** الذي كان ينقص جدولاً قائماً
 * منذ م.1 ([PHASE-8-STAGES.MD §1.3](../../../../docs/PHASE-8-STAGES.MD)).
 *
 * بلا هذه الشاشة تبقى `GET /student/me/announcements` نقطةً لا محتوى لها، وشاشةُ
 * الطالب وعداً لا يُنجَز — نظيرَ ما تحذّر منه [CLIENTS.md §3](CLIENTS.md) عن
 * أعذار ولي الأمر بلا طاقمٍ يراجعها.
 */
new #[Title('الإعلانات')] class extends Component {
    use InteractsWithInstitute;

    public ?int $editingId = null;

    public string $title = '';

    public string $body = '';

    public string $scope = 'all';

    /** @var array<int, int> */
    public array $circleIds = [];

    public bool $publishNow = true;

    public function mount(): void
    {
        $this->requireInstitute();
    }

    /**
     * @return Collection<int, Announcement>
     */
    #[Computed]
    public function announcements(): Collection
    {
        return app(AnnouncementQuery::class)->forInstitute($this->institute);
    }

    /**
     * حلقاتُ الدورة الجارية — وهي وحدها ما يصلح نطاقاً لإعلانٍ يُقرأ اليوم.
     *
     * @return Collection<int, CourseCircle>
     */
    #[Computed]
    public function circles(): Collection
    {
        $course = $this->institute?->currentCourse();

        if ($course === null) {
            return new Collection;
        }

        return CourseCircle::query()
            ->where('course_id', $course->id)
            ->with('circle')
            ->get();
    }

    public function create(): void
    {
        $this->reset('editingId', 'title', 'body', 'scope', 'circleIds', 'publishNow');
        $this->publishNow = true;
        $this->resetValidation();

        Flux::modal('announcement-form')->show();
    }

    public function edit(Announcement $announcement): void
    {
        $this->editingId = $announcement->id;
        $this->title = $announcement->title;
        $this->body = $announcement->body;
        $this->scope = $announcement->scope;
        $this->circleIds = array_map('intval', $announcement->scope_ids ?? []);
        $this->publishNow = $announcement->published_at !== null;
        $this->resetValidation();

        Flux::modal('announcement-form')->show();
    }

    public function save(): void
    {
        $validated = $this->validate([
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:5000'],
            'scope' => ['required', 'in:all,circle'],
            // نطاقُ «حلقة» بلا حلقةٍ واحدة إعلانٌ لا يقرؤه أحد — يُمنع في
            // الاستمارة لا يُكتشَف بعد النشر.
            'circleIds' => ['array', 'required_if:scope,circle'],
            'circleIds.*' => ['integer'],
        ], attributes: [
            'title' => 'العنوان',
            'body' => 'النص',
            'scope' => 'النطاق',
            'circleIds' => 'الحلقات',
        ]);

        app(PublishAnnouncement::class)->handle(
            $this->institute,
            [
                'title' => $validated['title'],
                'body' => $validated['body'],
                'scope' => $validated['scope'],
                'scope_ids' => $validated['circleIds'] ?? [],
                'published_at' => $this->publishNow ? now() : null,
            ],
            auth()->user(),
            $this->editingId === null ? null : Announcement::findOrFail($this->editingId),
        );

        unset($this->announcements);

        Flux::modal('announcement-form')->close();
        Flux::toast(
            variant: 'success',
            text: $this->publishNow ? 'نُشر الإعلان ويظهر للطلاب الآن.' : 'حُفظ الإعلان مسودّةً ولا يظهر لأحد.',
        );
    }

    public function unpublish(Announcement $announcement): void
    {
        // السحبُ إخفاءٌ لا حذف: الإعلانُ يبقى في السجلّ وتُفرَّغ `published_at`،
        // فمن سحبه بالخطأ يعيده بضغطة.
        $announcement->update(['published_at' => null]);

        unset($this->announcements);

        Flux::toast(variant: 'warning', text: 'سُحب الإعلان ولم يعد يظهر للطلاب.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="الإعلانات" :subheading="$this->institute?->name">
        <x-slot name="actions">
            <flux:button wire:click="create" variant="primary" icon="plus" data-test="new-announcement">إعلان جديد</flux:button>
        </x-slot>
    </x-page-header>

    <flux:text>
        الإعلانُ يظهر في تطبيق الطالب. ووجّهه إلى المعهد كلِّه أو إلى حلقاتٍ بعينها —
        وما وُجِّه إلى حلقةٍ لا يصل طلابَ غيرها.
    </flux:text>

    @if ($this->announcements->isEmpty())
        <div class="rounded-xl border border-sand-200 bg-white p-10 text-center dark:border-zinc-700 dark:bg-zinc-900">
            <flux:text>لا إعلاناتٍ بعد.</flux:text>
        </div>
    @else
        <div class="overflow-hidden rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900">
            <table class="w-full text-sm">
                <thead class="border-b border-sand-200 text-right dark:border-zinc-700">
                    <tr>
                        <th class="p-3 font-medium">العنوان</th>
                        <th class="p-3 font-medium">النطاق</th>
                        <th class="p-3 font-medium">الحالة</th>
                        <th class="p-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($this->announcements as $announcement)
                        <tr class="border-b border-sand-100 last:border-0 dark:border-zinc-800">
                            <td class="p-3">
                                <div class="font-medium">{{ $announcement->title }}</div>
                                <flux:text size="sm">{{ Str::limit($announcement->body, 80) }}</flux:text>
                            </td>
                            <td class="p-3">
                                {{ $announcement->scope === 'all' ? 'المعهد كلّه' : 'حلقات محدّدة (' . count($announcement->scope_ids ?? []) . ')' }}
                            </td>
                            <td class="latin-numerals p-3">
                                @if ($announcement->published_at === null)
                                    <flux:badge color="zinc" size="sm">مسودّة</flux:badge>
                                @else
                                    <flux:badge color="green" size="sm">منشور</flux:badge>
                                    <div class="text-xs text-ink-500 dark:text-zinc-400">{{ $announcement->published_at->format('Y-m-d H:i') }}</div>
                                @endif
                            </td>
                            <td class="p-3 text-left">
                                <flux:button wire:click="edit({{ $announcement->id }})" size="sm" variant="ghost" icon="pencil">تعديل</flux:button>
                                @if ($announcement->published_at !== null)
                                    <flux:button wire:click="unpublish({{ $announcement->id }})" size="sm" variant="ghost" icon="eye-slash">سحب</flux:button>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif

    <flux:modal name="announcement-form" class="w-full max-w-xl">
        <form wire:submit="save" class="flex flex-col gap-4">
            <flux:heading size="lg">{{ $editingId ? 'تعديل إعلان' : 'إعلان جديد' }}</flux:heading>

            <flux:input wire:model="title" label="العنوان" data-test="announcement-title" />
            <flux:textarea wire:model="body" label="النص" rows="5" data-test="announcement-body" />

            <flux:select wire:model.live="scope" label="النطاق" data-test="announcement-scope">
                <flux:select.option value="all">المعهد كلّه</flux:select.option>
                <flux:select.option value="circle">حلقات محدّدة</flux:select.option>
            </flux:select>

            @if ($scope === 'circle')
                <flux:checkbox.group wire:model="circleIds" label="الحلقات">
                    @foreach ($this->circles as $courseCircle)
                        <flux:checkbox value="{{ $courseCircle->id }}" label="{{ $courseCircle->circle?->name }}" />
                    @endforeach
                </flux:checkbox.group>

                @if ($this->circles->isEmpty())
                    <flux:text size="sm">لا حلقاتٍ في الدورة الجارية — فعّل دورةً أوّلاً.</flux:text>
                @endif
            @endif

            <flux:checkbox wire:model="publishNow" label="انشره الآن" description="المسودّة تُحفظ ولا تظهر لأحد." />

            <div class="flex justify-end gap-2">
                <flux:modal.close><flux:button variant="ghost">إلغاء</flux:button></flux:modal.close>
                <flux:button type="submit" variant="primary" data-test="save-announcement">حفظ</flux:button>
            </div>
        </form>
    </flux:modal>
</div>
