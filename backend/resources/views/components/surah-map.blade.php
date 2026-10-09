@props(['surahs'])

{{--
    خريطة المصحف: خلية لكل سورة، وشدّة اللون بقدر ما حُفظ منها.
    الترتيب من الفاتحة إلى الناس، ويقرأ من اليمين لأن التخطيط RTL.
--}}
<div {{ $attributes->class('flex flex-col gap-2') }}>
    <div class="grid grid-cols-[repeat(auto-fill,minmax(2.25rem,1fr))] gap-1">
        @foreach ($surahs as $surah)
            @php
                $ratio = $surah['ratio'];
                $shade = match (true) {
                    $ratio >= 1.0 => 'bg-primary text-on-primary',
                    $ratio >= 0.6 => 'bg-success text-on-primary',
                    $ratio >= 0.25 => 'bg-success-soft text-success',
                    $ratio > 0 => 'bg-bronze-soft text-bronze-ink',
                    default => 'bg-sunken text-muted',
                };
            @endphp

            <div
                class="avoid-break flex aspect-square flex-col items-center justify-center rounded-sm {{ $shade }}"
                title="{{ $surah['number'] }} · {{ $surah['name'] }} — {{ $surah['covered'] }}/{{ $surah['ayahs'] }} آية"
            >
                <span class="latin-numerals text-[0.6rem] leading-none font-semibold">{{ $surah['number'] }}</span>
            </div>
        @endforeach
    </div>

    <div class="flex flex-wrap items-center gap-3 text-xs text-muted">
        <span>مقياس التغطية:</span>
        @foreach ([
            'لم يبدأ' => 'bg-sunken',
            'أقل من الربع' => 'bg-bronze-soft',
            'ربع فأكثر' => 'bg-success-soft',
            'أغلبها' => 'bg-success',
            'مكتملة' => 'bg-primary',
        ] as $label => $swatch)
            <span class="inline-flex items-center gap-1">
                <span class="size-3 rounded {{ $swatch }}"></span>{{ $label }}
            </span>
        @endforeach
    </div>
</div>
