@props(['breakdown', 'heading' => 'توزيع الحضور — آخر أسبوعين'])

@php
    /** @var array{present: int, absent: int, late: int, excused: int} $breakdown */
    $total = max(array_sum($breakdown), 1);

    $bars = [
        ['key' => 'present', 'label' => 'حاضر', 'value' => $breakdown['present'], 'class' => 'bg-present'],
        ['key' => 'absent', 'label' => 'غائب', 'value' => $breakdown['absent'], 'class' => 'bg-absent'],
        ['key' => 'late', 'label' => 'متأخّر', 'value' => $breakdown['late'], 'class' => 'bg-late'],
        ['key' => 'excused', 'label' => 'مأذون', 'value' => $breakdown['excused'], 'class' => 'bg-excused'],
    ];
@endphp

<div {{ $attributes->class('rounded-xl border border-line bg-raised') }}>
    <div class="border-b border-line p-4">
        <flux:heading size="lg">{{ $heading }}</flux:heading>
    </div>

    @if (array_sum($breakdown) === 0)
        <flux:text class="p-6 text-center">لا توجد سجلات حضور بعد.</flux:text>
    @else
        <div class="flex flex-col gap-4 p-4">
            @foreach ($bars as $bar)
                <div>
                    <div class="flex items-center justify-between text-sm">
                        <span class="text-ink">{{ $bar['label'] }}</span>
                        <span class="latin-numerals text-muted">
                            {{ $bar['value'] }} · {{ round($bar['value'] / $total * 100, 1) }}%
                        </span>
                    </div>
                    <div class="mt-1.5 h-2.5 w-full overflow-hidden rounded-full bg-sunken">
                        <div class="h-full rounded-full {{ $bar['class'] }}" style="width: {{ round($bar['value'] / $total * 100, 1) }}%"></div>
                    </div>
                </div>
            @endforeach
        </div>
    @endif
</div>
