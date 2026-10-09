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
    <div role="status" class="flex items-center justify-center gap-2 border-b border-line bg-warning-soft px-4 py-2 text-center text-sm font-medium text-warning" data-test="foreign-institute-banner">
        <flux:icon icon="exclamation-triangle" variant="micro" />
        <span>أنت تعمل داخل «{{ $current->name }}» — وليس معهدك «{{ $home->name }}».</span>
    </div>
@elseif ($current !== null && $home === null)
    <div role="status" class="flex items-center justify-center gap-2 border-b border-line bg-warning-soft px-4 py-2 text-center text-sm font-medium text-warning" data-test="foreign-institute-banner">
        <flux:icon icon="exclamation-triangle" variant="micro" />
        <span>أنت تعمل داخل «{{ $current->name }}» بصلاحية عابرة للمعاهد.</span>
    </div>
@endif
