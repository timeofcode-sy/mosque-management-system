{{--
    تذييلُ الموقع العام — الرئيسيةُ وصفحتا «حول نزلاً» و«المطوِّر». بيانات التواصل العامة من config/nuzuln.php
    (لا تُعرض ما لم تُضبط)، والملكيةُ من config/developer.php. والأرقامُ لاتينية.
--}}
<footer id="contact" class="border-t border-line bg-raised py-8 text-sm text-muted" data-test="site-footer">
    <div class="nz-container flex flex-wrap items-center justify-between gap-x-6 gap-y-4">
        <a href="{{ route('home') }}" class="rounded-sm" aria-label="نزلاً">
            <x-app-logo-icon :small="true" class="size-10" alt="نزلاً" />
        </a>

        <address class="flex flex-wrap items-center gap-x-4 gap-y-1 not-italic">
            <span>{{ config('nuzuln.place') }}</span>
            @if (config('nuzuln.phone'))
                <a href="tel:{{ preg_replace('/\s+/', '', config('nuzuln.phone')) }}" dir="ltr" class="rounded-sm hover:text-ink hover:underline">{{ config('nuzuln.phone') }}</a>
            @endif
            @if (config('nuzuln.email'))
                <a href="mailto:{{ config('nuzuln.email') }}" dir="ltr" class="rounded-sm hover:text-ink hover:underline">{{ config('nuzuln.email') }}</a>
            @endif
        </address>

        <nav aria-label="عن الموقع" class="flex flex-wrap items-center gap-x-4 gap-y-1">
            <a href="{{ route('about') }}" class="rounded-sm hover:text-ink hover:underline">حول نزلاً</a>
            <a href="{{ route('developer') }}" class="rounded-sm hover:text-ink hover:underline">المطوِّر</a>
        </nav>

        <span>© <span dir="ltr">{{ now()->year }}</span> نزلاً · تطوير <a href="{{ route('developer') }}" class="rounded-sm hover:text-ink hover:underline" dir="ltr">{{ config('developer.name') }}</a></span>
    </div>
</footer>
