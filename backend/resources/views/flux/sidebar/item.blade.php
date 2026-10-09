@blaze

@php $tooltipPosition = $tooltipPosition ??= $attributes->pluck('tooltip:position'); @endphp
@php $tooltipKbd = $tooltipKbd ??= $attributes->pluck('tooltip:kbd'); @endphp
@php $tooltip = $tooltip ??= $attributes->pluck('tooltip'); @endphp
@php $iconTrailing ??= $attributes->pluck('icon:trailing'); @endphp
@php $iconVariant ??= $attributes->pluck('icon:variant'); @endphp

@props([
    'tooltipPosition' => 'right',
    'tooltipKbd' => null,
    'tooltip' => null,
    'iconVariant' => 'outline',
    'iconTrailing' => null,
    'badgeColor' => null,
    'iconDot' => null,
    'accent' => true,
    'badge' => null,
    'icon' => null,
])

{{--
    عنصر القائمة الجانبية على مواصفات SideNav في الهوية v3: ارتفاع 40px (و48px على اللمس)،
    زوايا 3px، والعنصر الحالي bronze-soft بنص bronze-ink وخطٍّ أثقل. التركيز بحلقة 2px.
    تعديلُ هذا الملف عن نسخة Flux الأصلية في الأصناف فقط، لا في البنية.
--}}
@php
$tooltip ??= $slot->isNotEmpty() ? (string) $slot : null;

$iconClasses = Flux::classes('size-5')
    ->add('in-data-flux-sidebar-group-dropdown:text-muted!')
    ->add('[[data-flux-sidebar-item]:hover_&]:text-current!');

$classes = Flux::classes()
    ->add('relative my-px flex min-h-10 w-full items-center gap-3 rounded-sm border border-transparent px-3 py-0 text-start')
    ->add('in-data-flux-sidebar-on-mobile:min-h-12')
    ->add('in-data-flux-sidebar-collapsed-desktop:w-10 in-data-flux-sidebar-collapsed-desktop:justify-center')
    ->add('has-data-flux-navlist-badge:not-in-data-flux-sidebar-collapsed-desktop:pe-1.5')
    ->add('text-ink transition-colors duration-150')
    ->add('hover:bg-sunken')
    ->add(match ($accent) {
        true => 'data-current:bg-bronze-soft data-current:text-bronze-ink data-current:font-semibold hover:data-current:bg-bronze-soft',
        false => 'data-current:bg-sunken data-current:font-semibold',
    })
    ->add('in-data-flux-sidebar-group-dropdown:w-auto! in-data-flux-sidebar-group-dropdown:px-2!')
    ;
@endphp

<flux:tooltip :position="$tooltipPosition">
    <flux:button-or-link :attributes="$attributes->class($classes)" data-flux-sidebar-item>
        <?php if ($icon): ?>
            <div class="relative">
                <?php if (is_string($icon) && $icon !== ''): ?>
                    <flux:icon :$icon :variant="$iconVariant" class="{!! $iconClasses !!}" />
                <?php else: ?>
                    {{ $icon }}
                <?php endif; ?>

                <?php if ($iconDot): ?>
                    <div class="absolute top-[-2px] end-[-2px]">
                        <div class="size-[6px] bg-bronze-ink"></div>
                    </div>
                <?php endif; ?>
            </div>
        <?php endif; ?>

        <?php if ($slot->isNotEmpty()): ?>
            <div class="
                in-data-flux-sidebar-collapsed-desktop:not-in-data-flux-sidebar-group-dropdown:hidden
                flex-1 truncate text-sm [[data-nav-footer]_&]:hidden [[data-nav-sidebar]_[data-nav-footer]_&]:block" data-content>{{ $slot }}</div>
        <?php endif; ?>

        <?php if (is_string($iconTrailing) && $iconTrailing !== ''): ?>
            <flux:icon :icon="$iconTrailing" :variant="$iconVariant" class="in-data-flux-sidebar-collapsed-desktop:not-in-data-flux-sidebar-group-dropdown:hidden size-4!" />
        <?php elseif ($iconTrailing): ?>
            {{ $iconTrailing }}
        <?php endif; ?>

        <?php if (isset($badge) && $badge !== ''): ?>
            <?php $badgeAttributes = Flux::attributesAfter('badge:', $attributes, ['color' => $badgeColor]); ?>
            <flux:navlist.badge :attributes="$badgeAttributes" class="in-data-flux-sidebar-collapsed-desktop:not-in-data-flux-sidebar-group-dropdown:hidden">{{ $badge }}</flux:navlist.badge>
        <?php endif; ?>
    </flux:button-or-link>

    <flux:tooltip.content :kbd="$tooltipKbd" class="not-in-data-flux-sidebar-collapsed-desktop:hidden in-data-flux-sidebar-group-dropdown:hidden cursor-default">
        {{ $tooltip }}
    </flux:tooltip.content>
</flux:tooltip>
