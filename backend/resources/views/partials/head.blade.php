<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
<meta name="theme-color" content="#F3F5F2" media="(prefers-color-scheme: light)" />
<meta name="theme-color" content="#0A241F" media="(prefers-color-scheme: dark)" />
<meta name="color-scheme" content="light dark" />

<title>
    {{ filled($title ?? null) ? $title.' · '.config('app.name', 'نزلاً') : config('app.name', 'نزلاً').' · نظام إدارة الحلقات في المساجد والمعاهد' }}
</title>

<link rel="icon" href="/favicon.ico" sizes="48x48">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/manifest.webmanifest">

{{-- الخطوط محلية (resources/fonts، تُبنى بتجزئةٍ في الاسم): نسبقُ تحميل الاثنين الأكثر استعمالاً فلا يومض النص ببديلٍ عند أول رسم. --}}
<link rel="preload" href="{{ Vite::asset('resources/fonts/IBMPlexSansArabic-Regular.woff2') }}" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="{{ Vite::asset('resources/fonts/IBMPlexSansArabic-SemiBold.woff2') }}" as="font" type="font/woff2" crossorigin>

@vite(['resources/css/app.css', 'resources/js/app.js'])

@fluxAppearance
