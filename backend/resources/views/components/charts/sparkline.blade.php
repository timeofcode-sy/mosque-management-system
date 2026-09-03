@props([
    'values' => [],
    'max' => null,
])

{{-- خط مصغّر داخل صف جدول: لا محاور ولا شبكة، الشكل وحده يكفي للمقارنة السريعة. --}}
@php
    $values = collect($values)->map(fn ($value) => (float) $value)->values();
    $peak = max(1e-9, (float) ($max ?? $values->max()));

    $viewWidth = 80;
    $viewHeight = 20;
    $step = $values->count() > 1 ? $viewWidth / ($values->count() - 1) : 0;

    $path = $values
        ->map(fn (float $value, int $index) => ($index === 0 ? 'M ' : 'L ')
            .round($index * $step, 2).','
            .round($viewHeight - min(1, max(0, $value / $peak)) * ($viewHeight - 2) - 1, 2))
        ->implode(' ');
@endphp

@if ($values->isNotEmpty())
    <svg
        viewBox="0 0 {{ $viewWidth }} {{ $viewHeight }}"
        preserveAspectRatio="none"
        {{ $attributes->class('h-5 w-20 overflow-visible') }}
        role="img"
        aria-hidden="true"
    >
        <path
            d="{{ $path }}"
            fill="none"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="chart-stroke stroke-brand-500 dark:stroke-brand-300"
            style="--dash-length: {{ $viewWidth * 2 }}"
        />
    </svg>
@endif
