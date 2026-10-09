@props(['heading', 'subheading' => null])

<div class="flex flex-wrap items-end justify-between gap-4">
    <div>
        <flux:heading size="xl" level="1" class="font-display text-[26px]/[38px]! font-semibold">{{ $heading }}</flux:heading>

        @if ($subheading)
            <flux:subheading class="mt-1">{{ $subheading }}</flux:subheading>
        @endif
    </div>

    @isset($actions)
        <div class="flex items-center gap-2">{{ $actions }}</div>
    @endisset
</div>
