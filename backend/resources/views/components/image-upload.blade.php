@props([
    'model',
    'label' => null,
    'existingUrl' => null,
    'shape' => 'square',
    'size' => 'h-24 w-24',
    'hint' => null,
])

@php
    $inputId = 'image-upload-'.preg_replace('/[^a-z0-9]+/i', '-', $model);
    $radius = $shape === 'circle' ? 'rounded-full' : 'rounded-xl';
@endphp

<flux:field>
    @if ($label)
        <flux:label>{{ $label }}</flux:label>
    @endif

    <div
        x-data="{
            previewUrl: null,
            existingUrl: @js($existingUrl),
            onChange(event) {
                const file = event.target.files[0];
                if (! file) { this.previewUrl = null; return; }
                this.previewUrl = URL.createObjectURL(file);
            },
        }"
        class="flex items-center gap-4"
    >
        <div class="{{ $size }} {{ $radius }} shrink-0 overflow-hidden border border-dashed border-sand-300 bg-sand-50 dark:border-zinc-600 dark:bg-zinc-800">
            <template x-if="previewUrl">
                <img :src="previewUrl" alt="" class="h-full w-full object-cover" />
            </template>

            <template x-if="! previewUrl && existingUrl">
                <img :src="existingUrl" alt="" class="h-full w-full object-cover" />
            </template>

            <template x-if="! previewUrl && ! existingUrl">
                <div class="flex h-full w-full items-center justify-center text-ink-500 dark:text-zinc-500">
                    <flux:icon name="photo" class="size-6" />
                </div>
            </template>
        </div>

        <div class="flex flex-col gap-2">
            <label
                for="{{ $inputId }}"
                class="inline-flex w-fit cursor-pointer items-center gap-2 rounded-lg border border-sand-300 bg-white px-3 py-1.5 text-sm font-medium text-ink-700 transition hover:bg-sand-50 dark:border-zinc-600 dark:bg-zinc-900 dark:text-zinc-200 dark:hover:bg-zinc-800"
            >
                <flux:icon name="arrow-up-tray" class="size-4" />
                اختر صورة
            </label>

            <input
                id="{{ $inputId }}"
                type="file"
                wire:model="{{ $model }}"
                accept="image/*"
                class="hidden"
                x-on:change="onChange"
            />

            <span wire:loading wire:target="{{ $model }}" class="text-xs text-ink-500 dark:text-zinc-400">جارٍ الرفع...</span>

            @if ($hint)
                <flux:text size="sm" class="text-ink-500 dark:text-zinc-400">{{ $hint }}</flux:text>
            @endif
        </div>
    </div>

    <flux:error name="{{ $model }}" />
</flux:field>
