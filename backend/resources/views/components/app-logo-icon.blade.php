@props([
    // الأحجام: من 48px فما فوق العلامة الكاملة؛ من 24 إلى 48 العلامة المصغّرة (بالألف الداخلية والنجمتين).
    'small' => false,
    'alt' => null,
])

{{--
    شعار نزلاً (v3). العلامة هي الكلمة نفسها فلا يُكتب «نزلاً» بجانبها.
    على الأرضية الفاتحة النسخة الخضراء، وعلى الليلية النحاسية (nz-only-light / nz-only-dark).
    المساحة الآمنة حول العلامة تُترك للمُستدعي. ولا تُدوَّر ولا تُظلَّل ولا يُعاد تلوينها.
--}}
@php($alt ??= config('app.name'))

<img src="{{ $small ? '/brand/logos/nuzuln-mark-small-night.svg' : '/brand/logos/nuzuln-mark-night.svg' }}" alt="{{ $alt }}" {{ $attributes->class('nz-only-light shrink-0 object-contain') }}>
<img src="{{ $small ? '/brand/logos/nuzuln-mark-small-bronze.svg' : '/brand/logos/nuzuln-mark-bronze.svg' }}" alt="{{ $alt }}" {{ $attributes->class('nz-only-dark shrink-0 object-contain') }}>
