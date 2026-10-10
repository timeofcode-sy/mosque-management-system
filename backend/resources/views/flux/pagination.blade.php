@blaze(fold: true)

<?php
// Flux يمرّر scroll-to عبر attributesAfter فلا يتحوّل إلى prop؛ هذا نفس الحلّ الأصلي.
extract(Flux::forwardedAttributes($attributes, ['scrollTo']));
?>

@props([
    'paginator' => null,
    'scrollTo' => $scrollTo ?? null,
])

{{--
    ترقيم الصفحات بنمط الهوية: ملخّص «عرض 1–20 من 78» ثم أزرار مربّعة بزاوية 3px (الصفحةُ الحالية primary مصمتة)،
    السابق والتالي بسهمين يتبعان اتجاه الواجهة، وصفحاتٌ بنافذةٍ حول الحالية مع نقاط الحذف. على الجوال: سابق ·
    «صفحة 2 من 4» · تالي بمساحة لمس 44px. الأرقام لاتينية. يستعمله `<flux:table :paginate>` وكل `<flux:pagination>`.

    تعريفُ الأزرار: حالٌ نشط `aria-current="page"`، والمعطَّل `aria-disabled` لا يُنقر، وكلُّها بتركيزٍ ظاهر.
--}}
@php
    $scrollToSelector = $scrollTo === true ? 'body' : $scrollTo;
    $scrollIntoView = ($scrollTo !== null && $scrollTo !== false)
        ? "(\$el.closest('{$scrollToSelector}') || \$el.closest('body').querySelector('{$scrollToSelector}')).scrollIntoView()"
        : '';

    $lengthAware = $paginator instanceof \Illuminate\Contracts\Pagination\LengthAwarePaginator;
    $current = $paginator->currentPage();
    $last = $lengthAware ? $paginator->lastPage() : null;
    $name = $paginator->getPageName();

    // نافذة الصفحات: الأولى والأخيرة وما حول الحالية، وبينها نقاط حذف.
    $pages = [];
    if ($lengthAware && $last > 1) {
        $window = collect([1, $last, $current - 1, $current, $current + 1])
            ->filter(fn ($page) => $page >= 1 && $page <= $last)
            ->unique()
            ->sort()
            ->values();

        $previous = null;
        foreach ($window as $page) {
            if ($previous !== null && $page - $previous > 1) {
                $pages[] = null;
            }
            $pages[] = $page;
            $previous = $page;
        }
    }

    $base = 'inline-flex size-11 sm:size-9 items-center justify-center rounded-sm border text-sm font-medium transition-colors';
    $idle = 'border-line bg-raised text-ink hover:bg-sunken';
    $disabled = 'border-line bg-raised text-muted opacity-50 pointer-events-none';
@endphp

@if ($paginator->hasPages() || ($lengthAware && $paginator->total() > 0))
    <nav {{ $attributes->class('flex flex-col gap-3 border-t border-line px-4 py-3 sm:flex-row sm:items-center sm:justify-between') }} aria-label="ترقيم الصفحات" data-flux-pagination>
        @if ($lengthAware && $paginator->total() > 0)
            <p class="latin-numerals text-sm text-muted">
                عرض <span class="font-semibold text-ink">{{ $paginator->firstItem() }}–{{ $paginator->lastItem() }}</span>
                من <span class="font-semibold text-ink">{{ $paginator->total() }}</span>
            </p>
        @else
            <span></span>
        @endif

        @if ($paginator->hasPages())
            <div class="flex items-center justify-between gap-1 sm:justify-end">
                {{-- السابق: سهمٌ يمين في RTL --}}
                @if ($paginator->onFirstPage())
                    <span aria-disabled="true" aria-label="السابق" class="{{ $base }} {{ $disabled }}"><flux:icon.chevron-right variant="micro" /></span>
                @else
                    <button type="button" wire:click="previousPage('{{ $name }}')" x-on:click="{{ $scrollIntoView }}" aria-label="السابق" class="{{ $base }} {{ $idle }}"><flux:icon.chevron-right variant="micro" /></button>
                @endif

                @if ($lengthAware)
                    {{-- الجوال: موضعٌ نصّي بدل سلسلة الأرقام --}}
                    <span class="latin-numerals px-3 text-sm text-muted sm:hidden">صفحة <span class="font-semibold text-ink">{{ $current }}</span> من {{ $last }}</span>

                    <div class="hidden items-center gap-1 sm:flex">
                        @foreach ($pages as $page)
                            @if ($page === null)
                                <span class="inline-flex size-9 items-center justify-center text-muted" aria-hidden="true">…</span>
                            @elseif ($page === $current)
                                <span aria-current="page" class="{{ $base }} latin-numerals border-primary bg-primary text-on-primary">{{ $page }}</span>
                            @else
                                <button type="button" wire:click="gotoPage({{ $page }}, '{{ $name }}')" x-on:click="{{ $scrollIntoView }}" aria-label="الصفحة {{ $page }}" class="{{ $base }} latin-numerals {{ $idle }}">{{ $page }}</button>
                            @endif
                        @endforeach
                    </div>
                @endif

                {{-- التالي: سهمٌ يسار في RTL --}}
                @if ($paginator->hasMorePages())
                    <button type="button" wire:click="nextPage('{{ $name }}')" x-on:click="{{ $scrollIntoView }}" aria-label="التالي" class="{{ $base }} {{ $idle }}"><flux:icon.chevron-left variant="micro" /></button>
                @else
                    <span aria-disabled="true" aria-label="التالي" class="{{ $base }} {{ $disabled }}"><flux:icon.chevron-left variant="micro" /></span>
                @endif
            </div>
        @endif
    </nav>
@endif
