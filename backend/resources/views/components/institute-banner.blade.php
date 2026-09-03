@php
    /**
     * شريط تنبيه رفيع حين يعمل المستخدم داخل معهد ليس معهده الأصلي.
     *
     * ليس تزييناً: الخطأ الشائع في نظام متعدّد المعاهد هو تحرير بيانات المعهد الخطأ
     * بعد تبديلٍ منسيّ — والشريط يجعل السياق مرئياً في كل شاشة بلا استثناء.
     */
    $current = \App\Support\PanelScope::resolve();
    $home = \App\Support\PanelScope::homeInstitute();
    $isForeign = $current !== null && $home !== null && $current->id !== $home->id;
@endphp

@if ($isForeign)
    <div class="flex items-center justify-center gap-2 bg-gold-500 px-4 py-1.5 text-center text-sm font-medium text-ink-900 dark:bg-gold-600 dark:text-white" data-test="foreign-institute-banner">
        <flux:icon icon="exclamation-triangle" variant="micro" />
        <span>أنت تعمل داخل «{{ $current->name }}» — وليس معهدك «{{ $home->name }}».</span>
    </div>
@elseif ($current !== null && $home === null)
    <div class="flex items-center justify-center gap-2 bg-gold-500 px-4 py-1.5 text-center text-sm font-medium text-ink-900 dark:bg-gold-600 dark:text-white" data-test="foreign-institute-banner">
        <flux:icon icon="exclamation-triangle" variant="micro" />
        <span>أنت تعمل داخل «{{ $current->name }}» بصلاحية عابرة للمعاهد.</span>
    </div>
@endif
