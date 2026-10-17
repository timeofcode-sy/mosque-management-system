@props(['breakdown', 'heading' => 'توزيع الحضور — آخر أسبوعين'])

@php
    /** @var array{present: int, absent: int, late: int, excused: int} $breakdown */
    $config = [
        'type' => 'donut',
        'name' => $heading,
        'totalLabel' => 'سجل',
        'segments' => [
            ['label' => 'حاضر', 'value' => $breakdown['present'], 'color' => 'present'],
            ['label' => 'غائب', 'value' => $breakdown['absent'], 'color' => 'absent'],
            ['label' => 'متأخّر', 'value' => $breakdown['late'], 'color' => 'late'],
            ['label' => 'غائب بعذر', 'value' => $breakdown['excused'], 'color' => 'excused'],
        ],
    ];
@endphp

<div {{ $attributes->class('rounded-xl border border-line bg-raised') }}>
    <div class="border-b border-line p-4">
        <flux:heading size="lg">{{ $heading }}</flux:heading>
    </div>

    @if (array_sum($breakdown) === 0)
        <flux:text class="p-6 text-center">لا توجد سجلات حضور بعد.</flux:text>
    @else
        <div class="p-2">
            <x-charts.canvas :config="$config" height="h-72" />
        </div>
    @endif
</div>
