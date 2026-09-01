<flux:callout icon="building-library" variant="warning">
    <flux:callout.heading>لا يوجد معهد بعد</flux:callout.heading>
    <flux:callout.text>
        ابدأ بإنشاء بيانات المعهد، ثم أنشئ الدورة الأولى ودواماتها وحلقاتها.
    </flux:callout.text>
    <x-slot name="actions">
        <flux:button :href="route('institute.edit')" wire:navigate variant="primary" size="sm">إنشاء المعهد</flux:button>
    </x-slot>
</flux:callout>
