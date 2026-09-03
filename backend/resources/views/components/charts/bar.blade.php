@props([
    'rows' => [],
    'unit' => '',
    'tone' => 'brand',
    'emptyText' => 'لا توجد بيانات في هذا المدى.',
])

{{--
    أعمدة أفقية — لا SVG هنا عمداً: أسماء الطلاب والحلقات عربية طويلة، ونصّ HTML
    يلتفّ ويُقصّ ويرث اتجاه RTL كما ينبغي، بينما نصّ <text> في SVG لا يفعل شيئاً من ذلك.
    الأشكال الهندسية (الدونات والمنحنى والخط المصغّر) تبقى SVG.
--}}
@php
    /** @var array<int, array{id?: int, name: string, value: float}> $rows */
    $rows = collect($rows)->values();
    $peak = max(1e-9, (float) $rows->max('value'), abs((float) $rows->min('value')));

    $fill = [
        'brand' => 'bg-brand-500 dark:bg-brand-400',
        'gold' => 'bg-gold-500',
        'danger' => 'bg-absent',
        'ink' => 'bg-ink-500',
    ][$tone] ?? 'bg-brand-500 dark:bg-brand-400';
@endphp

<div {{ $attributes->class('flex flex-col gap-3') }}>
    @forelse ($rows as $index => $row)
        @php($width = round(abs((float) $row['value']) / $peak * 100, 1))

        <div wire:key="bar-{{ $row['id'] ?? $index }}" class="avoid-break">
            <div class="flex items-baseline justify-between gap-3 text-sm">
                <span class="truncate text-ink-700 dark:text-zinc-200">{{ $row['name'] }}</span>
                <span class="latin-numerals shrink-0 font-medium text-ink-500 dark:text-zinc-400">
                    {{ $row['value'] }}{{ $unit }}
                </span>
            </div>

            <div class="mt-1.5 h-2.5 w-full overflow-hidden rounded-full bg-sand-100 dark:bg-zinc-800">
                <div
                    class="chart-bar h-full rounded-full {{ (float) $row['value'] < 0 ? 'bg-absent' : $fill }}"
                    style="width: {{ $width }}%; animation-delay: {{ $index * 60 }}ms"
                ></div>
            </div>
        </div>
    @empty
        <flux:text class="py-6 text-center">{{ $emptyText }}</flux:text>
    @endforelse
</div>
