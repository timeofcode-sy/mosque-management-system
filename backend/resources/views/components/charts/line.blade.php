@props([
    'points' => [],
    'valueKey' => 'rate',
    'labelKey' => 'date',
    'max' => 100,
    'emptyText' => 'لا توجد بيانات بعد.',
])

{{--
    منحنى ناعم: نقاط Catmull-Rom محوّلة إلى منحنيات Bézier تكعيبية، فالخط يمرّ بكل نقطة
    فعلاً (بخلاف Bézier الحرّ) ولا ينكسر عند الزوايا كما في polyline. الرسم يُخطّ من
    اليمين لليسار بـ stroke-dashoffset — اتجاه القراءة العربي.
--}}
@php
    $points = collect($points)->values();
    $count = $points->count();
    $max = max(1e-9, (float) $max);

    $viewWidth = 400;
    $viewHeight = 160;
    $padY = 14;

    $step = $count > 1 ? $viewWidth / ($count - 1) : 0;

    $coords = $points->map(fn ($point, int $index) => [
        'x' => round($index * $step, 2),
        'y' => round($padY + ($viewHeight - 2 * $padY) * (1 - min(1, max(0, (float) ($point[$valueKey] ?? 0) / $max))), 2),
        'point' => $point,
    ])->all();

    /** تحويل Catmull-Rom إلى Bézier: نقطتا التحكّم مشتقّتان من الجارين بمعامل 1/6. */
    $path = '';

    foreach ($coords as $i => $current) {
        if ($i === 0) {
            $path = "M {$current['x']},{$current['y']}";

            continue;
        }

        $previous = $coords[$i - 1];
        $before = $coords[$i - 2] ?? $previous;
        $after = $coords[$i + 1] ?? $current;

        $c1x = round($previous['x'] + ($current['x'] - $before['x']) / 6, 2);
        $c1y = round($previous['y'] + ($current['y'] - $before['y']) / 6, 2);
        $c2x = round($current['x'] - ($after['x'] - $previous['x']) / 6, 2);
        $c2y = round($current['y'] - ($after['y'] - $previous['y']) / 6, 2);

        $path .= " C {$c1x},{$c1y} {$c2x},{$c2y} {$current['x']},{$current['y']}";
    }

    $area = $path === '' ? '' : "{$path} L {$viewWidth},{$viewHeight} L 0,{$viewHeight} Z";
    $gradientId = 'chart-line-'.Illuminate\Support\Str::random(6);
@endphp

<div {{ $attributes->class('w-full') }}>
    @if ($count === 0)
        <flux:text class="py-6 text-center">{{ $emptyText }}</flux:text>
    @else
        <svg viewBox="0 0 {{ $viewWidth }} {{ $viewHeight }}" preserveAspectRatio="none" class="h-44 w-full overflow-visible" role="img" aria-label="منحنى">
            <defs>
                <linearGradient id="{{ $gradientId }}" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" class="text-brand-500" stop-color="currentColor" stop-opacity="0.28" />
                    <stop offset="100%" class="text-brand-500" stop-color="currentColor" stop-opacity="0" />
                </linearGradient>
            </defs>

            @foreach ([25, 50, 75] as $gridline)
                @php($gy = round($padY + ($viewHeight - 2 * $padY) * (1 - $gridline / 100), 2))
                <line x1="0" y1="{{ $gy }}" x2="{{ $viewWidth }}" y2="{{ $gy }}" class="stroke-sand-200 dark:stroke-zinc-700" stroke-width="1" stroke-dasharray="3 4" />
            @endforeach

            <path d="{{ $area }}" fill="url(#{{ $gradientId }})" class="chart-fade" style="animation-delay: 300ms" />

            <path
                d="{{ $path }}"
                fill="none"
                stroke-width="2.5"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="chart-stroke stroke-brand-600 dark:stroke-brand-300"
                style="--dash-length: {{ $viewWidth * 2 }}"
            />

            @foreach ($coords as $index => $coord)
                <circle
                    cx="{{ $coord['x'] }}" cy="{{ $coord['y'] }}" r="3.5"
                    stroke-width="2"
                    class="chart-fade fill-white stroke-brand-600 dark:fill-zinc-900 dark:stroke-brand-300"
                    style="animation-delay: {{ 300 + $index * 40 }}ms"
                >
                    <title>{{ $coord['point'][$labelKey] ?? '' }} · {{ $coord['point'][$valueKey] ?? 0 }}</title>
                </circle>
            @endforeach
        </svg>

        <div class="latin-numerals mt-2 flex justify-between text-xs text-ink-500 dark:text-zinc-400">
            <span>{{ $points->first()[$labelKey] ?? '' }}</span>
            <span>{{ $points->last()[$labelKey] ?? '' }}</span>
        </div>
    @endif
</div>
