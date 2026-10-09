@props(['code', 'title', 'message', 'action' => true])

<!DOCTYPE html>
<html lang="ar" dir="rtl">
    <head>
        @include('partials.head', ['title' => $title])
    </head>
    {{-- صفحات الأخطاء: تقول ما حدث وكيف يُصلح، وفيها طريقٌ واضح للعودة (جرد الشاشات: حالة «خطأ»). --}}
    <body class="nz-pattern-night min-h-dvh text-ink antialiased">
        <main class="flex min-h-dvh flex-col items-center justify-center gap-6 px-4 py-8 text-center">
            <a href="/" class="rounded-sm" aria-label="نزلاً · الصفحة الرئيسية">
                <img src="/brand/logos/nuzuln-mark.svg" alt="" class="h-20 w-auto">
            </a>

            <div class="w-full max-w-[460px] rounded-xl border border-line bg-raised p-6 shadow-card sm:p-8">
                <p class="latin-numerals font-display text-5xl font-bold text-primary" dir="ltr">{{ $code }}</p>
                <h1 class="mt-2 text-[26px] leading-[38px] font-bold">{{ $title }}</h1>
                <p class="mt-2 text-muted">{{ $message }}</p>

                @if ($action)
                    <div class="mt-6 flex flex-wrap justify-center gap-3">
                        <a href="{{ url('/') }}" class="nz-btn nz-btn--primary">العودة إلى الرئيسية</a>
                        <button type="button" onclick="history.back()" class="nz-btn nz-btn--secondary">رجوع</button>
                    </div>
                @endif
            </div>
        </main>
    </body>
</html>
