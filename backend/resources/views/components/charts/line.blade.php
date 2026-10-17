@props([
    'points' => [],
    'valueKey' => 'rate',
    'labelKey' => 'date',
    'max' => 100,
    'unit' => '%',
    'emptyText' => 'لا توجد بيانات بعد.',
])

{{--
    منحنى تفاعلي (ApexCharts — resources/js/charts.js): تلميحٌ عند المرور، ورسمٌ متحرّك، وألوان
    الهوية في الوضعين. نقطةٌ تحمل sessions = 0 فجوةٌ لا صفر، فلا يهبط المنحنى في أيام العطل.
--}}
@php
    $points = collect($points)->values();
    $config = [
        'type' => 'trend',
        'max' => $max,
        'unit' => $unit,
        'emptyText' => $emptyText,
        'points' => $points->map(function ($point) use ($valueKey, $labelKey) {
            $label = (string) ($point[$labelKey] ?? '');
            $empty = array_key_exists('sessions', $point) && (int) $point['sessions'] === 0;

            return [
                'label' => preg_match('/^\d{4}-\d{2}-\d{2}$/', $label) ? \Illuminate\Support\Carbon::parse($label)->format('j/n') : $label,
                'value' => $empty || $point[$valueKey] === null ? null : round((float) $point[$valueKey], 1),
                'detail' => isset($point['sessions']) && $point['sessions'] > 0 ? $point['sessions'].' جلسة' : null,
            ];
        })->all(),
    ];
@endphp

<div {{ $attributes->class('w-full') }}>
    @if ($points->isEmpty())
        <flux:text class="py-6 text-center">{{ $emptyText }}</flux:text>
    @else
        <x-charts.canvas :config="$config" />
    @endif
</div>
