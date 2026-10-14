@props([
    'segments' => [],
    'label' => null,
    'value' => null,
])

{{--
    دونات تفاعلي (ApexCharts — resources/js/charts.js): الشريحة تُبرز عند النقر، والتلميح يذكر
    العدد والنسبة، والمجموع في الوسط. صنفُ اللون stroke-present وأخواته يُترجم إلى رمز الهوية.
--}}
@php
    /** @var array<int, array{label: string, value: int|float, class: string}> $segments */
    $segments = collect($segments);
    $config = [
        'type' => 'donut',
        'name' => $label ?? 'توزيع',
        'totalLabel' => $label ?? 'المجموع',
        'segments' => $segments->map(fn (array $segment) => [
            'label' => $segment['label'],
            'value' => (float) $segment['value'],
            'color' => preg_replace('/^(stroke|bg|text)-/', '', $segment['class'] ?? 'primary'),
        ])->values()->all(),
    ];
@endphp

<div {{ $attributes->class('w-full') }}>
    @if ($segments->sum('value') <= 0)
        <flux:text class="py-6 text-center">لا توجد بيانات في هذا المدى.</flux:text>
    @else
        <x-charts.canvas :config="$config" height="h-72" />
    @endif
</div>
