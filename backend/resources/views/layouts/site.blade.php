@props(['title' => null, 'description' => null])

{{--
    هيكلُ صفحات الموقع العامة غير الرئيسية («حول نزلاً» و«المطوِّر»): رأسُ الواجهة نفسُه بشعاره
    وزرّ الدخول، وتذييلٌ يحمل روابطَ الصفحتين. والرئيسيةُ (welcome) باقيةٌ بهيكلها لأن رأسَها روابطُ أقسامها.
--}}
<!DOCTYPE html>
<html lang="ar" dir="rtl">
    <head>
        @include('partials.head', ['title' => $title])
        @if ($description)
            <meta name="description" content="{{ $description }}">
        @endif
    </head>
    <body class="bg-surface text-ink antialiased">
        <a href="#main-content" class="sr-only z-50 rounded-sm bg-primary px-4 py-2 text-on-primary focus:not-sr-only focus:fixed focus:start-4 focus:top-4">
            تخطَّ إلى المحتوى
        </a>

        <header class="sticky top-0 z-20 border-b border-line bg-raised">
            <div class="nz-container flex min-h-16 items-center gap-6">
                <a href="{{ route('home') }}" class="shrink-0 rounded-sm" aria-label="نزلاً · الصفحة الرئيسية">
                    <img class="nz-only-light h-11 w-auto" src="/brand/logos/nuzuln-lockup-horizontal-night.svg" alt="نزلاً · نظام إدارة الحلقات في المساجد والمعاهد">
                    <img class="nz-only-dark h-11 w-auto" src="/brand/logos/nuzuln-lockup-horizontal-bronze.svg" alt="نزلاً · نظام إدارة الحلقات في المساجد والمعاهد">
                </a>

                <nav aria-label="صفحات الموقع" class="ms-auto hidden items-center gap-6 text-sm font-medium sm:flex">
                    <a href="{{ route('home') }}" class="rounded-sm py-2 hover:text-bronze-ink">الرئيسية</a>
                    <a href="{{ route('about') }}" @class(['rounded-sm py-2 hover:text-bronze-ink', 'text-bronze-ink' => request()->routeIs('about')]) @if (request()->routeIs('about')) aria-current="page" @endif>حول نزلاً</a>
                    <a href="{{ route('developer') }}" @class(['rounded-sm py-2 hover:text-bronze-ink', 'text-bronze-ink' => request()->routeIs('developer')]) @if (request()->routeIs('developer')) aria-current="page" @endif>المطوِّر</a>
                </nav>

                <a href="{{ auth()->check() ? route('dashboard') : route('login') }}" class="nz-btn nz-btn--primary nz-btn--sm ms-auto sm:ms-0">
                    {{ auth()->check() ? 'حسابي' : 'تسجيل الدخول' }}
                </a>
            </div>
        </header>

        <main id="main-content" tabindex="-1">
            {{ $slot }}
        </main>

        <x-site-footer />

        @fluxScripts
    </body>
</html>
