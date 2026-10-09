@props([
    'selected' => 'present',
    'disabled' => false,
    'onSelect' => null,
    'testId' => null,
])

@php
    // حالات التفقّد بأزواج الهوية الثابتة (حاضر: success · متأخر: warning · مستأذن: info · غائب: danger).
    // المحدَّدة تُملأ بلونها الهادئ ويُكتب اسمها وتظهر علامة صحّ — فلا يكفي اللون وحده.
    $palette = [
        'present' => 'bg-success-soft text-success',
        'absent' => 'bg-danger-soft text-danger',
        'late' => 'bg-warning-soft text-warning',
        'excused' => 'bg-info-soft text-info',
    ];
@endphp

<div {{ $attributes->class('inline-flex overflow-hidden rounded-sm border border-line') }} role="radiogroup">
    @foreach (App\Enums\AttendanceStatus::cases() as $status)
        @php
            $isOn = $selected === $status->value;
            $classes = $isOn ? $palette[$status->value].' font-semibold' : 'bg-raised text-muted hover:bg-sunken';
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
            class="inline-flex min-h-10 items-center gap-1 border-s border-line px-3 text-[13px] font-medium transition-colors first:border-s-0 disabled:cursor-not-allowed disabled:opacity-60 {{ $classes }}"
        >
            @if ($isOn)
                <flux:icon icon="check" variant="micro" />
            @endif
            {{ $status->label() }}
        </button>
    @endforeach
</div>
