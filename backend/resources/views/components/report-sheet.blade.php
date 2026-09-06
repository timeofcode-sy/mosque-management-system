@props(['title', 'institute' => null, 'heading', 'subheading' => null, 'meta' => []])

<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title }}</title>

    @vite(['resources/css/app.css'])

    @include('partials.institute-theme', ['institute' => $institute])

    <style>
        /* الطباعة: A4 بهوامش معقولة، وإخفاء شريط الأدوات، ومنع كسر الجداول بين الصفحات */
        @page { size: A4; margin: 14mm 12mm; }

        @media print {
            .no-print { display: none !important; }
            body { background: #fff !important; }
            .sheet { box-shadow: none !important; border: 0 !important; margin: 0 !important; max-width: none !important; }
            tr, .avoid-break { break-inside: avoid; }
            thead { display: table-header-group; }
        }
    </style>
</head>
<body class="bg-sand-100 font-sans text-ink-900">
    <div class="no-print sticky top-0 z-10 flex flex-wrap items-center justify-between gap-2 border-b border-sand-300 bg-white px-4 py-3">
        <span class="text-sm text-ink-500">صفحة مهيّأة للطباعة — استخدم «طباعة» ثم «حفظ بصيغة PDF».</span>
        <button type="button" onclick="window.print()" class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-medium text-white hover:bg-brand-700">
            طباعة / حفظ PDF
        </button>
    </div>

    <div class="sheet mx-auto my-6 max-w-[210mm] bg-white p-8 shadow-sm">
        <header class="avoid-break flex items-start justify-between gap-6 border-b-2 border-brand-600 pb-4">
            <div>
                <h1 class="font-display text-2xl font-semibold text-brand-600">{{ $heading }}</h1>
                @if ($subheading)
                    <p class="mt-1 text-sm text-ink-500">{{ $subheading }}</p>
                @endif
            </div>

            <div class="text-end">
                @if ($institute?->logo_path)
                    <img src="{{ Storage::url($institute->logo_path) }}" alt="" class="mb-2 h-14 w-auto object-contain">
                @endif
                <p class="font-display text-lg font-semibold">{{ $institute?->name ?? config('app.name') }}</p>
                @if ($institute?->phone)
                    <p class="latin-numerals text-xs text-ink-500">{{ $institute->phone }}</p>
                @endif
            </div>
        </header>

        @if ($meta !== [])
            <dl class="avoid-break mt-4 grid grid-cols-2 gap-x-6 gap-y-2 text-sm sm:grid-cols-4">
                @foreach ($meta as $label => $value)
                    <div>
                        <dt class="text-xs text-ink-500">{{ $label }}</dt>
                        <dd class="latin-numerals font-medium">{{ $value ?: '—' }}</dd>
                    </div>
                @endforeach
            </dl>
        @endif

        <main class="mt-6">
            {{ $slot }}
        </main>

        <footer class="avoid-break mt-8 flex items-center justify-between border-t border-sand-300 pt-3 text-xs text-ink-500">
            <span>{{ $institute?->name ?? config('app.name') }}</span>
            <span class="latin-numerals">
                صدر في {{ now()->toDateString() }}
                @if ($hijri = App\Support\HijriDate::long(now())) · {{ $hijri }} @endif
            </span>
        </footer>
    </div>
</body>
</html>
