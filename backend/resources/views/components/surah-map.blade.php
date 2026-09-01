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
                    $ratio >= 1.0 => 'bg-brand-600 text-white',
                    $ratio >= 0.6 => 'bg-brand-400 text-white',
                    $ratio >= 0.25 => 'bg-brand-200 text-ink-900',
                    $ratio > 0 => 'bg-brand-100 text-ink-900',
                    default => 'bg-sand-200 text-ink-500 dark:bg-zinc-700 dark:text-zinc-400',
                };
            @endphp

            <div
                class="avoid-break flex aspect-square flex-col items-center justify-center rounded {{ $shade }}"
                title="{{ $surah['number'] }} · {{ $surah['name'] }} — {{ $surah['covered'] }}/{{ $surah['ayahs'] }} آية"
            >
                <span class="latin-numerals text-[0.6rem] leading-none font-semibold">{{ $surah['number'] }}</span>
            </div>
        @endforeach
    </div>

    <div class="flex flex-wrap items-center gap-3 text-xs text-ink-500 dark:text-zinc-400">
        <span>مقياس التغطية:</span>
        @foreach ([
            'لم يبدأ' => 'bg-sand-200 dark:bg-zinc-700',
            'أقل من الربع' => 'bg-brand-100',
            'ربع فأكثر' => 'bg-brand-200',
            'أغلبها' => 'bg-brand-400',
            'مكتملة' => 'bg-brand-600',
        ] as $label => $swatch)
            <span class="inline-flex items-center gap-1">
                <span class="size-3 rounded {{ $swatch }}"></span>{{ $label }}
            </span>
        @endforeach
    </div>
</div>
