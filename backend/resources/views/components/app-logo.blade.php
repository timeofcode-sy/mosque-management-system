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

{{--
    رأس القائمة الجانبية (SideNav في الهوية): علامة النظام ثم اسم المعهد. علامة نزلاً ثابتة لا يغيّرها
    معهد، وشعار المعهد الخاص (إن رُفع) يظهر بجانب اسمه صغيراً.
--}}
<a {{ $attributes->class('flex min-w-0 items-center gap-3 rounded-sm py-1 text-ink') }} data-flux-sidebar-brand>
    <x-app-logo-icon :small="true" class="size-11" :alt="config('app.name')" />

    <span class="flex min-w-0 items-center gap-2 in-data-flux-sidebar-collapsed-desktop:hidden">
        @if ($institute?->logo_path)
            <img src="{{ Storage::url($institute->logo_path) }}" alt="" class="size-7 shrink-0 rounded-sm object-contain" />
        @endif

        <span class="grid min-w-0 leading-tight">
            <span class="truncate text-[15px] font-bold">{{ $brandName }}</span>
            <span class="truncate text-xs text-muted">إدارة الحلقات</span>
        </span>
    </span>
</a>
