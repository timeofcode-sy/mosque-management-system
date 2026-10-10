<?php

namespace Tests\Feature\Livewire;

use App\Models\Curriculum;
use App\Models\CurriculumItem;
use Database\Seeders\CurriculumSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class CurriculumItemsTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->seed(CurriculumSeeder::class);
    }

    public function test_the_quran_parts_cannot_be_added_to(): void
    {
        $quran = $this->curriculum('quran');

        Livewire::test('pages::curricula.index')->call('createItem', $quran->getRouteKey());

        $this->assertSame(30, $quran->items()->count());
    }

    public function test_the_quran_parts_cannot_be_deleted(): void
    {
        $juz = $this->curriculum('quran')->items()->first();

        Livewire::test('pages::curricula.index')->call('deleteItem', $juz->getRouteKey());

        $this->assertModelExists($juz);
    }

    public function test_a_mutun_item_is_added_with_its_line_count(): void
    {
        $mutun = $this->curriculum('mutun');

        Livewire::test('pages::curricula.index')
            ->call('createItem', $mutun->getRouteKey())
            ->set('itemName', 'الرحبية')
            ->set('itemCount', 176)
            ->call('saveItem')
            ->assertHasNoErrors();

        $item = CurriculumItem::query()->where('name', 'الرحبية')->sole();

        $this->assertSame(176, $item->meta['abyat']);
    }

    public function test_the_quran_curriculum_and_its_parts_cannot_be_edited(): void
    {
        $quran = $this->curriculum('quran');
        $juz = $quran->items()->first();
        $juzName = $juz->name;

        Livewire::test('pages::curricula.index')
            ->call('edit', $quran->getRouteKey())
            ->assertSet('editingId', null)
            ->call('editItem', $juz->getRouteKey())
            ->assertSet('editingItemId', null)
            ->set('itemCurriculumId', $quran->id)
            ->set('editingItemId', $juz->id)
            ->set('itemName', 'الجزء الأول (تلاوة)')
            ->call('saveItem');

        $this->assertSame($juzName, $juz->refresh()->name);
        $this->assertSame(1, $juz->meta['juz']);
    }

    public function test_editing_a_counter_keeps_the_seeded_meta(): void
    {
        $item = CurriculumItem::query()->where('code', 'arbaeen-1')->sole();
        $item->update(['meta' => [...$item->meta, 'note' => 'kept']]);

        Livewire::test('pages::curricula.index')
            ->call('editItem', $item->getRouteKey())
            ->set('itemCount', 40)
            ->call('saveItem')
            ->assertHasNoErrors();

        $item->refresh();

        $this->assertSame(40, $item->meta['hadiths']);
        $this->assertSame('kept', $item->meta['note']);
    }

    public function test_the_seeder_carries_the_real_counts(): void
    {
        $this->assertSame(42, CurriculumItem::query()->where('code', 'arbaeen-1')->sole()->meta['hadiths']);
        $this->assertSame(34, CurriculumItem::query()->where('code', 'bayquniyyah')->sole()->meta['abyat']);
        $this->assertSame(107, CurriculumItem::query()->where('code', 'jazariyyah')->sole()->meta['abyat']);
    }

    private function curriculum(string $slug): Curriculum
    {
        return Curriculum::query()->where('slug', $slug)->sole();
    }
}
