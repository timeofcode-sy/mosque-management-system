@props([
    /** أرقامُ الأجزاء المحفوظة (1–30). */
    'memorized' => [],
    /** الجزءُ الذي يُحفظ الآن. */
    'current' => null,
    /** sm: شريطٌ مضغوط لصفوف الجداول. */
    'size' => 'md',
    'label' => true,
])

{{--
    الأجزاءُ الثلاثون خطوطاً بزاوية الشعار (nuzul-kit: .nz-juz): المحفوظُ أخضرُ عميق، والذي يُحفظ
    الآن نحاسيٌّ أطول — إشارةٌ لا يحملها اللونُ وحده — وما بقي بلون الحدود. الجزءُ الأول في البداية
    (يمين الصفحة)، كما في التطبيقات.
--}}
@php
    $memorized = array_map('intval', (array) $memorized);
    $count = count($memorized);
    $summary = "محفوظ {$count} من 30 جزءًا";
    $aria = $current === null ? $summary : "{$summary}، يحفظ الآن الجزء {$current}";
@endphp

<div {{ $attributes->class(['nz-juz latin-numerals', 'nz-juz--sm' => $size === 'sm']) }}>
    @if ($label)
        <div class="nz-juz__label">
            <b>{{ $summary }}</b>
            @if ($current !== null)
                <span>يحفظ الآن: الجزء {{ $current }}</span>
            @endif
        </div>
    @endif

    <div class="nz-juz__bar" role="img" aria-label="{{ $aria }}" title="{{ $aria }}">
        @for ($juz = 1; $juz <= 30; $juz++)
            <span @class([
                'nz-juz__seg',
                'nz-juz__seg--done' => in_array($juz, $memorized, true),
                'nz-juz__seg--current' => $juz === $current && ! in_array($juz, $memorized, true),
            ])></span>
        @endfor
    </div>
</div>
