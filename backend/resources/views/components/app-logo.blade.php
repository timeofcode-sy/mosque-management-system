@props([
    'sidebar' => false,
])

@php
    $institute = App\Models\Institute::query()->when(
        session('institute_id'),
        fn ($query) => $query->whereKey(session('institute_id')),
        fn ($query) => $query->where('is_active', true)->orderBy('id'),
    )->first();

    $brandName = $institute?->short_name ?: ($institute?->name ?: config('app.name'));
@endphp

@if($sidebar)
    <flux:sidebar.brand :name="$brandName" {{ $attributes }}>
        <x-slot name="logo" class="flex aspect-square size-8 items-center justify-center rounded-md bg-brand-600 text-white">
            @if ($institute?->logo_path)
                <img src="{{ Storage::url($institute->logo_path) }}" alt="{{ $brandName }}" class="size-8 rounded-md object-contain" />
            @else
                <x-app-logo-icon class="size-5 fill-current text-white" />
            @endif
        </x-slot>
    </flux:sidebar.brand>
@else
    <flux:brand :name="$brandName" {{ $attributes }}>
        <x-slot name="logo" class="flex aspect-square size-8 items-center justify-center rounded-md bg-brand-600 text-white">
            <x-app-logo-icon class="size-5 fill-current text-white" />
        </x-slot>
    </flux:brand>
@endif
