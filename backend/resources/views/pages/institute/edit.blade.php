<?php

use App\Concerns\InteractsWithInstitute;
use App\Models\Institute;
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

    public string $timezone = 'Asia/Riyadh';

    public bool $is_active = true;

    public $logo = null;

    public function mount(): void
    {
        $institute = $this->institute;

        if ($institute === null) {
            return;
        }

        $this->fill($institute->only('name', 'short_name', 'timezone', 'is_active'));
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
            'timezone' => ['required', 'string', 'max:64'],
            'is_active' => ['boolean'],
            'logo' => ['nullable', 'image', 'max:2048'],
        ]);

        $institute = $this->institute ?? new Institute;

        unset($validated['logo']);
        $institute->fill($validated);

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
        <flux:input wire:model="timezone" label="المنطقة الزمنية" />

        <x-image-upload
            model="logo"
            label="الشعار"
            :existing-url="$this->institute?->logo_path ? Storage::url($this->institute->logo_path) : null"
            hint="PNG أو JPG، حتى 2 ميغابايت"
        />

        <flux:switch wire:model="is_active" label="المعهد فعّال" />

        <flux:button type="submit" variant="primary" data-test="save-institute">حفظ</flux:button>
    </form>
</div>
