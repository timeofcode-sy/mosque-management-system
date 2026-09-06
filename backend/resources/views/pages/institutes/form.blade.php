<?php

use App\Actions\CreateInstitute;
use App\Models\Institute;
use App\Support\AttendanceSettings;
use App\Support\InstituteForm;
use App\Support\InstituteTheme;
use App\Support\PointsSettings;
use Flux\Flux;
use Livewire\Attributes\Title;
use Livewire\Component;
use Livewire\WithFileUploads;

/**
 * إنشاء معهد أو تحريره من نطاق المشرف الأعلى — الشاشة نفسها بحالتين.
 *
 * لا تستعمل InteractsWithInstitute: هذه الشاشة تحرّر معهداً بعينه لا «المعهد العامل»،
 * وربطُها بالجلسة كان سيُبدّل السياق بمجرّد فتح معهد آخر للتعديل.
 */
new #[Title('معهد')] class extends Component {
    use WithFileUploads;

    public ?Institute $institute = null;

    public string $name = '';

    public string $short_name = '';

    public string $phone = '';

    public string $email = '';

    public string $address = '';

    public bool $is_active = true;

    public $logo = null;

    /**
     * @var array<string, mixed>
     */
    public array $points = [];

    /**
     * ألوان المعهد الثلاثة — تُقرأ وتُكتب في institutes.settings['theme'].
     *
     * @var array<string, string>
     */
    public array $theme = [];

    /**
     * @var array<string, mixed>
     */
    public array $attendance = [];

    public function mount(?Institute $institute = null): void
    {
        $this->points = PointsSettings::for($institute)->toArray();
        $this->theme = InstituteTheme::for($institute)->toArray();
        $this->attendance = AttendanceSettings::for($institute)->toArray();

        if ($institute?->exists !== true) {
            return;
        }

        $this->institute = $institute;
        $this->fill($institute->only('name', 'short_name', 'is_active'));
        $this->phone = (string) $institute->phone;
        $this->email = (string) $institute->email;
        $this->address = (string) $institute->address;
    }

    public function save(): void
    {
        $validated = $this->validate(InstituteForm::rules(), attributes: InstituteForm::attributes());

        $attributes = InstituteForm::attributesFor($this->institute, $validated, $this->points, $this->logo);

        if ($this->institute === null) {
            app(CreateInstitute::class)->handle($attributes);

            Flux::toast(variant: 'success', text: 'أُنشئ المعهد ومعه دورة أولى مسودّة.');
            $this->redirect(route('institutes.index'), navigate: true);

            return;
        }

        $this->institute->fill($attributes)->save();
        $this->logo = null;

        Flux::toast(variant: 'success', text: 'حُفظت بيانات المعهد.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header
        :heading="$institute ? 'تعديل معهد' : 'معهد جديد'"
        :subheading="$institute?->name ?: 'يُنشأ معه دورة أولى مسودّة ليعمل التسجيل والتفقّد'"
    >
        <x-slot name="actions">
            <flux:button :href="route('institutes.index')" wire:navigate variant="ghost" icon="arrow-right">رجوع</flux:button>
        </x-slot>
    </x-page-header>

    <form wire:submit="save" class="max-w-2xl space-y-6 rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
        <x-institute-form-fields
            :logo-url="$institute?->logo_path ? Storage::url($institute->logo_path) : null"
        />

        <flux:button type="submit" variant="primary" data-test="save-institute">حفظ</flux:button>
    </form>
</div>
