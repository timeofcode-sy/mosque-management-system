@props([
    'segments' => [],
    'label' => null,
    'value' => null,
])

{{--
    دونات بأقواس stroke-dasharray: كل قوس يُرسم من موضعه بالإزاحة، ويتتابع الرسم
    بتأخير متدرّج. لا JS — والدائرة مستديرة فعلاً لأن viewBox مربّع ونسبته محفوظة.
--}}
@php
    /** @var array<int, array{label: string, value: int|float, class: string}> $segments */
    $segments = collect($segments)->filter(fn (array $segment) => (float) $segment['value'] > 0)->values();
    $total = (float) $segments->sum('value');

    $radius = 60;
    $circumference = 2 * M_PI * $radius;

    $offset = 0.0;
    $arcs = $segments->map(function (array $segment) use (&$offset, $total, $circumference): array {
        $share = $total > 0 ? (float) $segment['value'] / $total : 0.0;
        $length = $share * $circumference;
        $arc = [...$segment, 'share' => $share, 'length' => $length, 'offset' => $offset];
        $offset += $length;

        return $arc;
    });
@endphp

<div {{ $attributes->class('flex flex-wrap items-center justify-center gap-6') }}>
    @if ($total <= 0)
        <flux:text class="py-6 text-center">لا توجد بيانات في هذا المدى.</flux:text>
    @else
        <div class="relative">
            <svg viewBox="0 0 160 160" class="size-40" role="img" aria-label="{{ $label ?? 'توزيع' }}">
                <circle cx="80" cy="80" r="{{ $radius }}" fill="none" stroke-width="18" class="stroke-sand-100 dark:stroke-zinc-800" />

                {{-- التدوير −90 درجة يبدأ القوس من أعلى الدائرة لا من يمينها --}}
                <g transform="rotate(-90 80 80)">
                    @foreach ($arcs as $index => $arc)
                        <circle
                            cx="80" cy="80" r="{{ $radius }}"
                            fill="none"
                            stroke-width="18"
                            stroke-linecap="butt"
                            class="chart-stroke {{ $arc['class'] }}"
                            style="
                                --dash-length: {{ round($arc['length'], 2) }};
                                stroke-dasharray: {{ round($arc['length'], 2) }} {{ round($circumference - $arc['length'], 2) }};
                                stroke-dashoffset: 0;
                                transform: rotate({{ round($arc['offset'] / $circumference * 360, 3) }}deg);
                                transform-origin: 80px 80px;
                                animation-delay: {{ $index * 120 }}ms;
                            "
                        />
                    @endforeach
                </g>
            </svg>

            @if ($value !== null)
                <div class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                    <span class="latin-numerals font-display text-2xl font-semibold text-ink-900 dark:text-zinc-100">{{ $value }}</span>
                    @if ($label)
                        <span class="text-xs text-ink-500 dark:text-zinc-400">{{ $label }}</span>
                    @endif
                </div>
            @endif
        </div>

        <div class="flex flex-col gap-2 text-sm">
            @foreach ($arcs as $arc)
                <span class="flex items-center gap-2">
                    <span class="size-3 rounded {{ str_replace('stroke-', 'bg-', $arc['class']) }}"></span>
                    <span class="text-ink-700 dark:text-zinc-200">{{ $arc['label'] }}</span>
                    <span class="latin-numerals text-ink-500 dark:text-zinc-400">
                        {{ $arc['value'] }} · {{ round($arc['share'] * 100, 1) }}%
                    </span>
                </span>
            @endforeach
        </div>
    @endif
</div>
