<x-layouts::app.sidebar :title="$title ?? null">
    {{--
        المحتوى يتوقّف عند content-max (1200px) على الشاشات العريضة ويذهب الفائض إلى الهوامش، بهوامش
        16 / 24 / 32px حسب العرض (الهوية: bp-compact / bp-medium / bp-expanded).
    --}}
    <flux:main id="main-content" class="flex min-h-dvh flex-col !p-4 sm:!p-6 lg:!p-8" tabindex="-1">
        <div class="mx-auto w-full max-w-[1200px] flex-1">
            {{ $slot }}
        </div>

        <x-panel-footer />
    </flux:main>
</x-layouts::app.sidebar>
