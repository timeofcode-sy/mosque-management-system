@props(['rate' => null, 'showBar' => false])

@php
    $value = $rate === null ? null : (float) $rate;
    $tone = match (true) {
        $value === null => 'text-ink-500 dark:text-zinc-400',
        $value >= 90 => 'text-present dark:text-brand-300',
        $value >= 75 => 'text-gold-600 dark:text-gold-400',
        default => 'text-absent dark:text-red-400',
    };
@endphp

<div {{ $attributes->class('latin-numerals inline-flex items-center gap-2') }}>
    <span class="{{ $tone }} font-medium">
        {{ $value === null ? '—' : rtrim(rtrim(number_format($value, 1, '.', ''), '0'), '.').'%' }}
    </span>

    @if ($showBar && $value !== null)
        <span class="h-1.5 w-16 overflow-hidden rounded-full bg-sand-200 dark:bg-zinc-700">
            <span class="block h-full rounded-full bg-current {{ $tone }}" style="width: {{ min(100, max(0, $value)) }}%"></span>
        </span>
    @endif
</div>
