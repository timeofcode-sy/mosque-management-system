<?php

use App\Concerns\InteractsWithInstitute;
use App\Enums\AttendanceStatus;
use App\Enums\RecitationGrade;
use App\Models\Institute;
use App\Support\PointsSettings;
use Flux\Flux;
use Illuminate\Support\Facades\Session;
use Livewire\Attributes\Title;
use Livewire\Component;
use Livewire\WithFileUploads;

new #[Title('بيانات المعهد')] class extends Component {
    use InteractsWithInstitute, WithFileUploads;

    public string $name = '';

    public string $short_name = '';

    public string $phone = '';

    public string $email = '';

    public string $address = '';

    public bool $is_active = true;

    public $logo = null;

    /**
     * إعدادات النقاط كما تُعرض في النموذج — تُقرأ وتُكتب في institutes.settings['points'].
     *
     * @var array<string, mixed>
     */
    public array $points = [];

    public function mount(): void
    {
        $institute = $this->institute;

        $this->points = PointsSettings::for($institute)->toArray();

        if ($institute === null) {
            return;
        }

        $this->fill($institute->only('name', 'short_name', 'is_active'));
        $this->phone = (string) $institute->phone;
        $this->email = (string) $institute->email;
        $this->address = (string) $institute->address;
    }

    public function save(): void
    {
        $validated = $this->validate([
            'name' => ['required', 'string', 'max:255'],
            'short_name' => ['nullable', 'string', 'max:100'],
            'phone' => ['nullable', 'string', 'max:32'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'is_active' => ['boolean'],
            'logo' => ['nullable', 'image', 'max:2048'],
            'points.quran_per_15_lines' => ['required', 'numeric', 'min:0', 'max:1000'],
            'points.hadith_per_item' => ['required', 'numeric', 'min:0', 'max:1000'],
            'points.mutun_per_bayt' => ['required', 'numeric', 'min:0', 'max:1000'],
            'points.attendance.*' => ['required', 'numeric', 'min:-100', 'max:100'],
            'points.grade_multiplier.*' => ['required', 'numeric', 'min:0', 'max:200'],
        ], attributes: [
            'points.quran_per_15_lines' => 'نقاط كل خمسة عشر سطراً',
            'points.hadith_per_item' => 'نقاط الحديث الواحد',
            'points.mutun_per_bayt' => 'نقاط البيت الواحد',
        ]);

        $institute = $this->institute ?? new Institute;

        unset($validated['logo'], $validated['points']);
        $institute->fill($validated);

        // الإعدادات الأخرى في العمود تبقى كما هي — نستبدل مفتاح points وحده.
        $institute->settings = [...(array) $institute->settings, 'points' => $this->points];

        if ($this->logo !== null) {
            $institute->logo_path = $this->logo->store('institutes', 'public');
        }

        $institute->save();

        Session::put('institute_id', $institute->id);
        unset($this->institute, $this->currentCourse);
        $this->logo = null;

        Flux::toast(variant: 'success', text: 'حُفظت بيانات المعهد.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="بيانات المعهد" subheading="الاسم والشعار وبيانات التواصل — تظهر في الواجهات والتقارير" />

    <form wire:submit="save" class="max-w-2xl space-y-6 rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
        <flux:input wire:model="name" label="اسم المعهد" required autofocus />
        <flux:input wire:model="short_name" label="الاسم المختصر" description="يُستخدم في ترويسة التقارير الضيقة" />

        <div class="grid gap-6 sm:grid-cols-2">
            <flux:input wire:model="phone" label="الهاتف" />
            <flux:input wire:model="email" type="email" label="البريد الإلكتروني" />
        </div>

        <flux:input wire:model="address" label="العنوان" />

        <x-image-upload
            model="logo"
            label="الشعار"
            :existing-url="$this->institute?->logo_path ? Storage::url($this->institute->logo_path) : null"
            hint="PNG أو JPG، حتى 2 ميغابايت"
        />

        <flux:switch wire:model="is_active" label="المعهد فعّال" />

        <flux:separator text="النقاط" />

        <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">
            نقاط القرآن تُحتسب للأسطر الجديدة دون المكرّر، ثم يضربها معامل التقدير.
        </flux:text>

        <div class="grid gap-6 sm:grid-cols-3">
            <flux:input
                wire:model="points.quran_per_15_lines"
                type="number" step="0.5" min="0"
                label="القرآن · لكل ١٥ سطراً"
                class="latin-numerals"
                data-test="points-quran"
            />
            <flux:input
                wire:model="points.hadith_per_item"
                type="number" step="0.5" min="0"
                label="الحديث · لكل حديث"
                class="latin-numerals"
                data-test="points-hadith"
            />
            <flux:input
                wire:model="points.mutun_per_bayt"
                type="number" step="0.5" min="0"
                label="المتون · لكل بيت"
                class="latin-numerals"
                data-test="points-mutun"
            />
        </div>

        <div>
            <flux:heading size="sm">نقاط الحضور</flux:heading>
            <div class="mt-3 grid gap-6 sm:grid-cols-4">
                @foreach (AttendanceStatus::cases() as $status)
                    <flux:input
                        wire:key="points-attendance-{{ $status->value }}"
                        wire:model="points.attendance.{{ $status->value }}"
                        type="number" step="0.5"
                        :label="$status->label()"
                        class="latin-numerals"
                        :data-test="'points-attendance-'.$status->value"
                    />
                @endforeach
            </div>
        </div>

        <div>
            <flux:heading size="sm">معامل التقدير</flux:heading>
            <flux:text size="sm" class="mt-1 text-ink-500 dark:text-zinc-400">نسبة مئوية تُضرب في نقاط التسميع.</flux:text>
            <div class="mt-3 grid gap-6 sm:grid-cols-3">
                @foreach (RecitationGrade::cases() as $grade)
                    <flux:input
                        wire:key="points-grade-{{ $grade->value }}"
                        wire:model="points.grade_multiplier.{{ $grade->value }}"
                        type="number" step="5" min="0" max="200"
                        :label="$grade->label().' %'"
                        class="latin-numerals"
                        :data-test="'points-grade-'.$grade->value"
                    />
                @endforeach
            </div>
        </div>

        <flux:button type="submit" variant="primary" data-test="save-institute">حفظ</flux:button>
    </form>
</div>
