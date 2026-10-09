<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" dir="rtl">
    <head>
        @include('partials.head')
    </head>
    {{--
        صفحات الدخول: النموذج في وسط الصفحة على أرضية night بالنقش (شاشة «تسجيل الدخول» في جرد الشاشات).
        البطاقة raised فتبقى مقروءةً في السمتين، والعلامة المتدرّجة لا تُوضع إلا على night.
    --}}
    <body class="nz-pattern-night min-h-dvh text-ink antialiased">
        <a href="#main-content" class="sr-only z-50 rounded-sm bg-primary px-4 py-2 text-on-primary focus:not-sr-only focus:fixed focus:start-4 focus:top-4">
            تخطَّ إلى المحتوى
        </a>

        <div class="flex min-h-dvh flex-col items-center justify-center gap-6 px-4 py-8 sm:px-6">
            <a href="{{ route('home') }}" class="flex flex-col items-center gap-3 rounded-sm" wire:navigate>
                <img src="/brand/logos/nuzuln-mark.svg" alt="{{ config('app.name') }}" class="h-24 w-auto sm:h-28">
            </a>

            <main id="main-content" tabindex="-1" class="w-full max-w-[420px] rounded-xl border border-line bg-raised p-6 shadow-card sm:p-8">
                {{ $slot }}
            </main>

            <p class="text-center text-xs text-[#A8BBB2]">
                نزلاً · نظام إدارة الحلقات في المساجد والمعاهد
            </p>
        </div>

        @persist('toast')
            <flux:toast.group>
                <flux:toast />
            </flux:toast.group>
        @endpersist

        @fluxScripts
    </body>
</html>
