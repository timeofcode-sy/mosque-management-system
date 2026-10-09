@props(['label', 'value', 'hint' => null, 'tone' => 'brand'])

@php
    $tones = [
        'brand' => 'text-primary',
        'gold' => 'text-bronze-ink',
        'danger' => 'text-danger',
        'ink' => 'text-ink',
    ];
@endphp

<div {{ $attributes->class('rounded-xl border border-line bg-raised p-4') }}>
    <flux:text size="sm" class="text-muted">{{ $label }}</flux:text>
    <p class="latin-numerals mt-2 font-display text-3xl font-semibold {{ $tones[$tone] ?? $tones['brand'] }}">{{ $value }}</p>

    @if ($hint)
        <flux:text size="sm" class="mt-1 text-muted">{{ $hint }}</flux:text>
    @endif
</div>
