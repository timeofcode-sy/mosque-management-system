@props(['points', 'heading' => 'منحنى الحضور — آخر أسبوعين'])

@php
    /** @var \Illuminate\Support\Collection<int, array{date: string, rate: float, sessions: int}> $points */
    $points = collect($points);
    $withSessions = $points->where('sessions', '>', 0);
    $count = max($points->count(), 1);

    // صندوق عرض عريض بنسبة ثابتة (400×160) حتى لا يُشوَّه بالتمدد غير المتساوي على المحورين،
    // فتبقى النقاط دائرية فعلاً بدل أن تُرسَم كبيضاوية مضغوطة.
    $viewWidth = 400;
    $viewHeight = 160;
    $padY = 12;

    $step = $count > 1 ? $viewWidth / ($count - 1) : 0;
    $coords = $points->values()->map(fn (array $point, int $i) => [
        'x' => round($i * $step, 2),
        'y' => round($padY + (($viewHeight - 2 * $padY) * (100 - min(100, max(0, $point['rate'])))) / 100, 2),
        'point' => $point,
    ]);

    $line = $coords->map(fn (array $c) => $c['x'].','.$c['y'])->implode(' ');
    $area = $coords->isEmpty() ? '' : "0,{$viewHeight} ".$line." {$viewWidth},{$viewHeight}";
@endphp

<div {{ $attributes->class('rounded-xl border border-sand-200 bg-white dark:border-zinc-700 dark:bg-zinc-900') }}>
    <div class="flex flex-wrap items-center justify-between gap-2 border-b border-sand-200 p-4 dark:border-zinc-700">
        <flux:heading size="lg">{{ $heading }}</flux:heading>

        @if ($withSessions->isNotEmpty())
            <flux:text size="sm" class="latin-numerals text-ink-500 dark:text-zinc-400">
                المعدّل {{ round($withSessions->avg('rate'), 1) }}% · {{ $withSessions->count() }} يوم تفقّد
            </flux:text>
        @endif
    </div>

    @if ($withSessions->isEmpty())
        <flux:text class="p-6 text-center">لا توجد جلسات مغلقة بعد — المنحنى يظهر بعد أول تفقّد مكتمل.</flux:text>
    @else
        <div class="p-4">
            {{-- الرسم بـ SVG خالص: لا مكتبة مخططات، ويطبع مع التقرير كما هو على الشاشة --}}
            <svg viewBox="0 0 {{ $viewWidth }} {{ $viewHeight }}" preserveAspectRatio="none" class="h-40 w-full overflow-visible" role="img" aria-label="{{ $heading }}">
                @foreach ([25, 50, 75] as $gridline)
                    @php $gy = $padY + (($viewHeight - 2 * $padY) * (100 - $gridline)) / 100; @endphp
                    <line x1="0" y1="{{ $gy }}" x2="{{ $viewWidth }}" y2="{{ $gy }}" class="stroke-sand-200 dark:stroke-zinc-700" stroke-width="1" />
                @endforeach

                <polygon points="{{ $area }}" class="fill-brand-500/10" />
                <polyline
                    points="{{ $line }}"
                    fill="none"
                    class="stroke-brand-600 dark:stroke-brand-300"
                    stroke-width="2"
                    stroke-linejoin="round"
                    stroke-linecap="round"
                />

                @foreach ($coords as $c)
                    @if ($c['point']['sessions'] > 0)
                        <circle cx="{{ $c['x'] }}" cy="{{ $c['y'] }}" r="3.5" class="fill-white stroke-brand-600 dark:fill-zinc-900 dark:stroke-brand-300" stroke-width="2" />
                    @endif
                @endforeach
            </svg>

            <div class="latin-numerals mt-2 flex justify-between text-xs text-ink-500 dark:text-zinc-400">
                <span>{{ $points->first()['date'] ?? '' }}</span>
                <span>{{ $points->last()['date'] ?? '' }}</span>
            </div>
        </div>
    @endif
</div>
