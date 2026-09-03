@php
    /**
     * حالتان لا واحدة: من يملك إنشاء المعاهد يُدعى إلى إنشاء معهد، ومن لا يملك
     * يُخبَر أن حسابه غير مرتبط بمعهد — وهذه هي الحالة التي كان السقوط الافتراضي
     * إلى «أوّل معهد فعّال» يخفيها بأن يُدخله معهداً ليس له.
     */
    $canManage = auth()->user()?->can('institutes.manage') || auth()->user()?->can('settings.manage');
@endphp

@if ($canManage)
    <flux:callout icon="building-library" variant="warning">
        <flux:callout.heading>لا يوجد معهد بعد</flux:callout.heading>
        <flux:callout.text>
            ابدأ بإنشاء بيانات المعهد، ثم أنشئ الدورة الأولى ودواماتها وحلقاتها.
        </flux:callout.text>
        <x-slot name="actions">
            <flux:button
                :href="auth()->user()?->can('institutes.manage') ? route('institutes.create') : route('institute.edit')"
                wire:navigate
                variant="primary"
                size="sm"
            >إنشاء المعهد</flux:button>
        </x-slot>
    </flux:callout>
@else
    <flux:callout icon="building-library" variant="warning" data-test="no-linked-institute">
        <flux:callout.heading>حسابك غير مرتبط بمعهد</flux:callout.heading>
        <flux:callout.text>
            راجع مشرف النظام ليربط حسابك بسجلّك في المعهد — بلا هذا الربط لا تُعرض لك بيانات.
        </flux:callout.text>
    </flux:callout>
@endif
