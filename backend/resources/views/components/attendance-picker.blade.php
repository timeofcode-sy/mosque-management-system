@props([
    'selected' => 'present',
    'disabled' => false,
    'onSelect' => null,
    'testId' => null,
])

@php
    // ألوان حالات التفقّد من توكنات الهوية (--color-present/absent/late/excused).
    $palette = [
        'present' => ['on' => 'bg-present text-white border-present', 'off' => 'text-present border-sand-300 hover:bg-present/10 dark:border-zinc-600'],
        'absent' => ['on' => 'bg-absent text-white border-absent', 'off' => 'text-absent border-sand-300 hover:bg-absent/10 dark:border-zinc-600'],
        'late' => ['on' => 'bg-late text-ink-900 border-late', 'off' => 'text-late border-sand-300 hover:bg-late/10 dark:border-zinc-600'],
        'excused' => ['on' => 'bg-excused text-white border-excused', 'off' => 'text-excused border-sand-300 hover:bg-excused/10 dark:border-zinc-600'],
    ];
@endphp

<div {{ $attributes->class('inline-flex rounded-lg shadow-xs') }} role="radiogroup">
    @foreach (App\Enums\AttendanceStatus::cases() as $status)
        @php
            $isOn = $selected === $status->value;
            $classes = $palette[$status->value][$isOn ? 'on' : 'off'];
        @endphp

        <button
            type="button"
            role="radio"
            aria-checked="{{ $isOn ? 'true' : 'false' }}"
            @disabled($disabled)
            @if (! $disabled && $onSelect)
                wire:click="{{ sprintf($onSelect, "'".$status->value."'") }}"
            @endif
            @if ($testId)
                data-test="{{ $testId }}-{{ $status->value }}"
            @endif
            class="border px-3 py-1.5 text-sm font-medium transition first:rounded-s-lg last:rounded-e-lg disabled:cursor-not-allowed disabled:opacity-60 {{ $classes }} -me-px last:me-0"
        >
            {{ $status->label() }}
        </button>
    @endforeach
</div>
