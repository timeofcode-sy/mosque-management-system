@props(['label', 'value', 'hint' => null, 'tone' => 'brand'])

@php
    $tones = [
        'brand' => 'text-brand-600 dark:text-brand-300',
        'gold' => 'text-gold-600 dark:text-gold-400',
        'danger' => 'text-red-600 dark:text-red-400',
        'ink' => 'text-ink-700 dark:text-zinc-200',
    ];
@endphp

<div {{ $attributes->class('rounded-xl border border-sand-200 bg-white p-4 dark:border-zinc-700 dark:bg-zinc-900') }}>
    <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">{{ $label }}</flux:text>
    <p class="latin-numerals mt-2 font-display text-3xl font-semibold {{ $tones[$tone] ?? $tones['brand'] }}">{{ $value }}</p>

    @if ($hint)
        <flux:text size="sm" class="mt-1 text-ink-500 dark:text-zinc-400">{{ $hint }}</flux:text>
    @endif
</div>
