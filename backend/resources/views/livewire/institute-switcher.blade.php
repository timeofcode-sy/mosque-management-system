<?php

use App\Models\Institute;
use App\Support\PanelScope;
use Illuminate\Database\Eloquent\Collection;
use Livewire\Attributes\Computed;
use Livewire\Component;

/**
 * مبدّل المعهد في الشريط الجانبي.
 *
 * لا يظهر إلا لمن له أكثر من معهد أو دورٌ عابر للمعاهد — ولمستخدم المعهد الواحد
 * (وهم الأغلبية) لا وجود له أصلاً، فلا يشغل مكاناً ولا يوحي بخيار لا يملكه.
 *
 * التبديل يمرّ بـ PanelScope::switchTo فيُرفض معهدٌ لا دور للمستخدم فيه، ثم إعادة
 * تحميل كاملة (navigate: false): كل الخصائص المحسوبة في اللوحة مشتقّة من المعهد.
 */
new class extends Component
{
    #[Computed]
    public function current(): ?Institute
    {
        return PanelScope::resolve();
    }

    /**
     * @return Collection<int, Institute>
     */
    #[Computed]
    public function institutes(): Collection
    {
        return PanelScope::institutesFor(auth()->user());
    }

    public function switchTo(Institute $institute): void
    {
        if (! PanelScope::switchTo($institute)) {
            abort(403);
        }

        $this->redirect(route('dashboard'), navigate: false);
    }
}; ?>

<div>
    @if ($this->institutes->count() > 1)
        <flux:dropdown position="bottom" align="start" class="w-full">
            <flux:button
                icon="building-library"
                icon-trailing="chevron-down"
                variant="subtle"
                size="sm"
                class="w-full justify-between"
                data-test="institute-switcher"
            >
                <span class="truncate">{{ $this->current?->short_name ?: $this->current?->name ?: 'اختر معهداً' }}</span>
            </flux:button>

            <flux:menu>
                <flux:menu.radio.group>
                    @foreach ($this->institutes as $institute)
                        <flux:menu.radio
                            wire:key="switch-{{ $institute->id }}"
                            wire:click="switchTo('{{ $institute->uuid }}')"
                            :checked="$institute->id === $this->current?->id"
                        >
                            {{ $institute->name }}
                            @unless ($institute->is_active)
                                <flux:badge size="sm" color="zinc" class="ms-2">معطّل</flux:badge>
                            @endunless
                        </flux:menu.radio>
                    @endforeach
                </flux:menu.radio.group>
            </flux:menu>
        </flux:dropdown>
    @endif
</div>
