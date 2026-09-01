@props(['heading', 'subheading' => null])

<div class="flex flex-wrap items-end justify-between gap-4">
    <div>
        <flux:heading size="xl">{{ $heading }}</flux:heading>

        @if ($subheading)
            <flux:subheading class="mt-1">{{ $subheading }}</flux:subheading>
        @endif
    </div>

    @isset($actions)
        <div class="flex items-center gap-2">{{ $actions }}</div>
    @endisset
</div>
