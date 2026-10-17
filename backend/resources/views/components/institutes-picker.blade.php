@props(['institutes'])

{{-- معاهدُ «مشرف معاهد»: يُسنَد الدورُ في كلِّ معهدٍ مختار، فيبدّل بينها ويقارن بينها في «لوحة المعاهد». --}}
<flux:checkbox.group wire:model="new_institutes" label="المعاهد التي يشرف عليها" description="يرى هذه المعاهد وحدها، ويبدّل بينها من أعلى القائمة" data-test="region-institutes">
    @foreach ($institutes as $option)
        <flux:checkbox value="{{ $option->id }}" :label="$option->name" />
    @endforeach
</flux:checkbox.group>
