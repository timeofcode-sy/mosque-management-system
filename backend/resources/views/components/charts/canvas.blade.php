@props(['config', 'height' => 'h-60'])

{{--
    حاضنة مخطط ApexCharts (resources/js/charts.js). wire:ignore يترك رسمَ المكتبة لها، ومفتاحُ
    البيانات يبدّل العنصرَ كلَّه متى تغيّرت — فيُرسم من جديد لا فوق رسمٍ قديم.
--}}
<div
    wire:key="chart-{{ md5(json_encode($config)) }}"
    wire:ignore
    x-data="nzChart(@js($config))"
    {{ $attributes->class(['latin-numerals w-full', $height]) }}
    role="img"
    aria-label="{{ $config['name'] ?? 'مخطط' }}"
>
    <div x-ref="canvas" class="size-full"></div>
</div>
