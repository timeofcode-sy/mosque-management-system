{{--
    تذييل اللوحة: هادئ ومحدود بـ content-max كالمحتوى. يحمل اسم النظام ونطاقه وسنة الإصدار؛ والأرقام لاتينية.
--}}
<footer class="mx-auto mt-10 w-full max-w-[1200px] border-t border-line pt-4 text-xs text-muted" data-test="panel-footer">
    <div class="flex flex-wrap items-center justify-between gap-x-6 gap-y-2">
        <span class="flex items-center gap-2">
            <x-app-logo-icon :small="true" class="size-6" alt="" />
            <span>نزلاً · نظام إدارة الحلقات في المساجد والمعاهد</span>
        </span>

        <span class="flex flex-wrap items-center gap-x-4 gap-y-1">
            <a href="https://nuzuln.com" class="rounded-sm hover:text-ink hover:underline" dir="ltr">nuzuln.com</a>
            <span>© {{ now()->year }}</span>
        </span>
    </div>
</footer>
