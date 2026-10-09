@blaze(fold: true, unsafe: ['icon:trailing', 'icon:variant'])

@props([
    'expandable' => false,
    'expanded' => true,
    'heading' => null,
])

{{--
    مجموعة القائمة الجانبية: عنوان القسم 12px بوزن 600 بلون ink-muted كما في `nz-sidenav__section` في الهوية.
    المجموعات القابلة للطيّ لا يستعملها النظام، فبقي فرعها في Flux الأصلي دون تعديل.
--}}
<?php if ($expandable && $heading): ?>
    <ui-disclosure {{ $attributes->class('group/disclosure in-data-flux-sidebar-collapsed-desktop:hidden') }} @if ($expanded === true) open @endif data-flux-sidebar-group>
        <button type="button" class="group/disclosure-button my-px flex min-h-10 w-full items-center rounded-sm text-ink hover:bg-sunken">
            <div class="ps-3.5 pe-3.5">
                <flux:icon.chevron-down class="hidden size-3! group-data-open/disclosure-button:block" />
                <flux:icon.chevron-left class="block size-3! group-data-open/disclosure-button:hidden" />
            </div>

            <span class="text-sm font-medium leading-none">{{ $heading }}</span>
        </button>

        <div class="relative hidden data-open:block ps-7" @if ($expanded === true) data-open @endif>
            <div class="absolute inset-y-[3px] start-0 ms-5 w-px bg-line"></div>

            <div class="flex flex-col">
                {{ $slot }}
            </div>
        </div>
    </ui-disclosure>
<?php elseif ($heading): ?>
    <div {{ $attributes->class('flex flex-col in-data-flux-sidebar-collapsed-desktop:hidden') }} data-flux-sidebar-group>
        <div class="px-3 pt-4 pb-1">
            <div class="text-xs font-semibold leading-[18px] text-muted">{{ $heading }}</div>
        </div>

        <div class="flex flex-col">
            {{ $slot }}
        </div>
    </div>
<?php else: ?>
    <div {{ $attributes->class('flex flex-col in-data-flux-sidebar-collapsed-desktop:hidden') }} data-flux-sidebar-group>
        {{ $slot }}
    </div>
<?php endif; ?>
