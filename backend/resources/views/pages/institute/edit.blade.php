<?php

use App\Concerns\InteractsWithInstitute;
use App\Models\Institute;
use App\Support\AttendanceSettings;
use App\Support\InstituteForm;
use App\Support\InstituteTheme;
use App\Support\PanelScope;
use App\Support\PointsSettings;
use Flux\Flux;
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

    public function mount(): void
    {
        $institute = $this->institute;

        $this->points = PointsSettings::for($institute)->toArray();
        $this->theme = InstituteTheme::for($institute)->toArray();
        $this->attendance = AttendanceSettings::for($institute)->toArray();

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
        $validated = $this->validate(InstituteForm::rules(), attributes: InstituteForm::attributes());

        $institute = $this->institute ?? new Institute;

        $institute->fill(InstituteForm::attributesFor($this->institute, $validated, $this->points, $this->logo));
        $institute->save();

        PanelScope::activate($institute);
        unset($this->institute, $this->currentCourse);
        $this->logo = null;

        Flux::toast(variant: 'success', text: 'حُفظت بيانات المعهد.');
    }
}; ?>

<div class="flex w-full flex-col gap-6">
    <x-page-header heading="بيانات المعهد" subheading="الاسم والشعار وبيانات التواصل — تظهر في الواجهات والتقارير" />

    <form wire:submit="save" class="max-w-2xl space-y-6 rounded-xl border border-sand-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-900">
        <x-institute-form-fields
            :logo-url="$this->institute?->logo_path ? Storage::url($this->institute->logo_path) : null"
        />

        <flux:button type="submit" variant="primary" data-test="save-institute">حفظ</flux:button>
    </form>
</div>
