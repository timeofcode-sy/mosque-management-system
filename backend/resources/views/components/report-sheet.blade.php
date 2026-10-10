@props(['title', 'institute' => null, 'heading', 'subheading' => null, 'meta' => []])

<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title }}</title>

    <link rel="icon" href="/favicon.svg" type="image/svg+xml">
    @vite(['resources/css/app.css'])

    <style>
        /* الطباعة: A4 بهوامش معقولة، وإخفاء شريط الأدوات، ومنع كسر الجداول بين الصفحات */
        @page { size: A4 portrait; margin: 14mm 12mm 24mm; }

        /* app.css يثبّت html/body على ارتفاع الشاشة مع overflow:hidden لتمرير لوحة التحكم؛ هنا يجب أن تتدفّق الصفحة
           بطولها، وإلا اقتُطع التقرير عند أول صفحة في الطباعة وتعذّر تمريره على الشاشة. */
        html, body { height: auto; min-height: 100%; overflow: visible; }
        body { display: block; }

        .sheet-footer {
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
            background: var(--mist) url('/brand/pattern/nuzuln-pattern-tile-mist.svg') 0 0 / 90px auto;
            border-top: 2px solid var(--bronze);
        }

        @media print {
            * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            .no-print { display: none !important; }
            body { background: #fff !important; }
            .sheet { box-shadow: none !important; border: 0 !important; margin: 0 !important; max-width: none !important; padding: 0 !important; }
            .sheet-footer { position: fixed; inset-inline: 0; bottom: 0; }
            tr, .avoid-break { break-inside: avoid; }
            thead { display: table-header-group; }
        }
    </style>
</head>
<body class="bg-sunken font-sans text-ink">
    <div class="no-print sticky top-0 z-10 flex flex-wrap items-center justify-between gap-2 border-b border-line bg-raised px-4 py-3">
        <span class="text-sm text-muted">صفحة مهيّأة للطباعة — استخدم «طباعة» ثم «حفظ بصيغة PDF».</span>
        <button type="button" onclick="window.print()" class="nz-btn nz-btn--primary nz-btn--sm">
            طباعة / حفظ PDF
        </button>
    </div>

    {{-- الورق الرسمي (letterhead-a4 في الهوية): شعار النظام أعلى اليمين، ثم خطّ نحاسي، ثم المحتوى. --}}
    <div class="sheet mx-auto my-6 max-w-[210mm] bg-raised p-8 pb-24 shadow-card">
        <header class="avoid-break">
            <div class="flex items-start justify-between gap-6">
                <img src="/brand/logos/nuzuln-lockup-horizontal-night.svg" alt="نزلاً · نظام إدارة الحلقات في المساجد والمعاهد" class="h-14 w-auto">

                <div class="text-end text-xs text-muted">
                    <p>التاريخ: <bdi dir="ltr" class="latin-numerals">{{ now()->toDateString() }}</bdi></p>
                    @if ($hijri = App\Support\HijriDate::long(now()))
                        <p class="latin-numerals">{{ $hijri }}</p>
                    @endif
                </div>
            </div>

            <div class="mt-4 border-t-2 border-bronze"></div>

            <div class="mt-4 flex items-start justify-between gap-6">
                <div>
                    <h1 class="font-display text-[26px] leading-[1.4] font-semibold text-ink">{{ $heading }}</h1>
                    @if ($subheading)
                        <p class="mt-1 text-sm text-muted">{{ $subheading }}</p>
                    @endif
                </div>

                <div class="flex items-center gap-3 text-end">
                    @if ($institute?->logo_path)
                        <img src="{{ Storage::url($institute->logo_path) }}" alt="" class="h-12 w-auto object-contain">
                    @endif
                    <div>
                        <p class="text-base font-semibold">{{ $institute?->name ?? config('app.name') }}</p>
                        @if ($institute?->phone)
                            <p class="latin-numerals text-xs text-muted" dir="ltr">{{ $institute->phone }}</p>
                        @endif
                    </div>
                </div>
            </div>
        </header>

        @if ($meta !== [])
            <dl class="avoid-break mt-4 grid grid-cols-2 gap-x-6 gap-y-2 text-sm sm:grid-cols-4">
                @foreach ($meta as $label => $value)
                    <div>
                        <dt class="text-xs text-muted">{{ $label }}</dt>
                        <dd class="latin-numerals font-medium">{{ $value ?: '—' }}</dd>
                    </div>
                @endforeach
            </dl>
        @endif

        <main class="mt-6">
            {{ $slot }}
        </main>
    </div>

    <footer class="sheet-footer px-8 py-3 text-xs text-muted">
        <div class="mx-auto flex max-w-[210mm] items-center justify-between gap-4">
            <span>{{ $institute?->name ?? config('app.name') }}</span>
            <span class="flex items-center gap-2">
                <span>نزلاً · نظام إدارة الحلقات</span>
                <span dir="ltr">{{ config('nuzuln.domain') }}</span>
            </span>
        </div>
    </footer>
</body>
</html>
