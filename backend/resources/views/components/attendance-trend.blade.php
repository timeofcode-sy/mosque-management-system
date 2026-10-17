@props(['points', 'heading' => 'منحنى الحضور — آخر أسبوعين'])

@php
    /** @var \Illuminate\Support\Collection<int, array{date: string, rate: float|null, sessions: int}> $points */
    $points = collect($points);
    $withSessions = $points->where('sessions', '>', 0);

    // يومٌ بلا جلسة فجوةٌ في المنحنى لا هبوطٌ إلى الصفر: الخطّ يصل أيامَ التفقّد وحدها.
    $config = [
        'type' => 'trend',
        'name' => 'نسبة الحضور',
        'points' => $points->map(fn (array $point) => [
            'label' => \Illuminate\Support\Carbon::parse($point['date'])->format('j/n'),
            'value' => $point['sessions'] > 0 && $point['rate'] !== null ? round($point['rate'], 1) : null,
            'detail' => $point['sessions'] > 0 ? $point['sessions'].' جلسة' : null,
        ])->values()->all(),
    ];
@endphp

<div {{ $attributes->class('rounded-xl border border-line bg-raised') }}>
    <div class="flex flex-wrap items-center justify-between gap-2 border-b border-line p-4">
        <flux:heading size="lg">{{ $heading }}</flux:heading>

        @if ($withSessions->isNotEmpty())
            <flux:text size="sm" class="latin-numerals text-muted">
                المعدّل {{ round($withSessions->avg('rate'), 1) }}% · {{ $withSessions->count() }} يوم تفقّد
            </flux:text>
        @endif
    </div>

    @if ($withSessions->isEmpty())
        <flux:text class="p-6 text-center">لا توجد جلسات مغلقة بعد — المنحنى يظهر بعد أول تفقّد مكتمل.</flux:text>
    @else
        <div class="px-2 pt-2 pb-1">
            <x-charts.canvas :config="$config" />
        </div>
    @endif
</div>
