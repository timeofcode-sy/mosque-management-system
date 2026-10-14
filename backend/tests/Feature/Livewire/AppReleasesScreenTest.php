<?php

namespace Tests\Feature\Livewire;

use App\Models\AppRelease;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * شاشةُ «تحديثات التطبيقات» — أداةُ المبرمج التي تنشر ما تسأل عنه التطبيقات.
 */
class AppReleasesScreenTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();

        $developer = User::factory()->create();
        $developer->assignGlobalRole('developer');
        $this->actingAs($developer);

        Storage::fake(AppRelease::DISK);
    }

    public function test_the_screen_renders_a_card_for_each_target(): void
    {
        AppRelease::factory()->build(5)->create();

        $this->get(route('system.app-releases'))
            ->assertOk()
            ->assertSee('data-test="target-mobile"', false)
            ->assertSee('data-test="target-admin_android"', false)
            ->assertSee('data-test="target-admin_desktop"', false)
            ->assertSee('1.0.0-beta.5');
    }

    public function test_an_exported_file_fills_the_form_from_its_name_and_publishes(): void
    {
        $file = UploadedFile::fake()->createWithContent('nuzuln-admin-android-1.0.0-beta.6-b6.apk', 'apk-bytes');

        Livewire::test('pages::system.app-releases')
            ->call('create')
            ->set('package', $file)
            ->assertSet('target', 'admin_android')
            ->assertSet('version', '1.0.0-beta.6')
            ->assertSet('buildNumber', 6)
            ->set('notes', "التفقّد أسرع\nإصلاح المزامنة")
            ->set('isMandatory', true)
            ->call('save')
            ->assertHasNoErrors();

        $release = AppRelease::query()->sole();

        $this->assertSame('admin_android', $release->target->value);
        $this->assertTrue($release->is_mandatory);
        $this->assertTrue($release->isPublished());
        $this->assertSame(hash('sha256', 'apk-bytes'), $release->sha256);
        $this->assertSame(['التفقّد أسرع', 'إصلاح المزامنة'], $release->noteLines());
        Storage::disk(AppRelease::DISK)->assertExists($release->file_path);
    }

    public function test_the_windows_target_refuses_an_apk(): void
    {
        Livewire::test('pages::system.app-releases')
            ->call('create', 'admin_desktop')
            ->set('version', '1.0.0')
            ->set('buildNumber', 6)
            ->set('package', UploadedFile::fake()->createWithContent('app.apk', 'x'))
            ->call('save')
            ->assertHasErrors(['package']);
    }

    public function test_a_build_number_is_unique_per_target(): void
    {
        AppRelease::factory()->build(6)->create();

        Livewire::test('pages::system.app-releases')
            ->call('create', 'mobile')
            ->set('version', '1.0.0-beta.6')
            ->set('buildNumber', 6)
            ->set('source', 'url')
            ->set('externalUrl', 'https://example.com/a.apk')
            ->call('save')
            ->assertHasErrors(['buildNumber' => 'unique']);

        // والرقمُ نفسُه لهدفٍ آخر مقبول.
        Livewire::test('pages::system.app-releases')
            ->call('create', 'admin_android')
            ->set('version', '1.0.0-beta.6')
            ->set('buildNumber', 6)
            ->set('source', 'url')
            ->set('externalUrl', 'https://example.com/a.apk')
            ->call('save')
            ->assertHasNoErrors();
    }

    public function test_a_new_release_suggests_the_next_build_number(): void
    {
        AppRelease::factory()->build(6)->create();

        Livewire::test('pages::system.app-releases')
            ->call('create', 'mobile')
            ->assertSet('buildNumber', 7);
    }

    public function test_editing_keeps_the_file_and_the_first_publish_date(): void
    {
        $release = AppRelease::factory()->build(6)->create([
            'external_url' => null, 'file_path' => 'app-releases/mobile/a.apk', 'file_name' => 'a.apk',
            'published_at' => now()->subWeek(),
        ]);
        $published = $release->published_at->toDateTimeString();

        Livewire::test('pages::system.app-releases')
            ->call('edit', $release->uuid)
            ->assertSet('source', 'file')
            ->set('title', 'عنوانٌ جديد')
            ->call('save')
            ->assertHasNoErrors();

        $release->refresh();
        $this->assertSame('عنوانٌ جديد', $release->title);
        $this->assertSame('app-releases/mobile/a.apk', $release->file_path);
        $this->assertSame($published, $release->published_at->toDateTimeString());
    }

    public function test_unpublishing_and_deleting(): void
    {
        $release = AppRelease::factory()->build(6)->create();

        Livewire::test('pages::system.app-releases')
            ->call('togglePublished', $release->uuid);

        $this->assertNull($release->refresh()->published_at);

        Livewire::test('pages::system.app-releases')
            ->call('confirmDelete', $release->uuid)
            ->call('delete');

        $this->assertModelMissing($release);
    }
}
