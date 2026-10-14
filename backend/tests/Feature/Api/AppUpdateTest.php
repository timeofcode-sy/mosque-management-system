<?php

namespace Tests\Feature\Api;

use App\Actions\SaveAppRelease;
use App\Enums\AppTarget;
use App\Models\AppInstall;
use App\Models\AppRelease;
use App\Queries\AppUpdateQuery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * تحديثاتُ التطبيقات من جهة الجهاز: السؤالُ بلا توكن، والإلزامُ ممّا فات، والتنزيلُ المستأنَف.
 */
class AppUpdateTest extends TestCase
{
    use RefreshDatabase;

    private const DEVICE = '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';

    public function test_an_up_to_date_device_is_told_there_is_nothing(): void
    {
        AppRelease::factory()->build(5)->create();

        $this->getJson('/api/v1/app-updates/check?target=mobile&build=5')
            ->assertOk()
            ->assertJson(['target' => 'mobile', 'current_build' => 5, 'update' => null]);
    }

    public function test_an_older_device_gets_the_latest_release_and_every_change_it_missed(): void
    {
        AppRelease::factory()->build(4)->create(['notes' => "- أولاً\n- ثانياً"]);
        AppRelease::factory()->build(6)->create(['title' => 'الأحدث', 'notes' => "• ثالثاً\n\n4) رابعاً"]);

        $update = $this->getJson('/api/v1/app-updates/check?target=mobile&build=3')
            ->assertOk()
            ->json('update');

        $this->assertSame(6, $update['build_number']);
        $this->assertSame('الأحدث', $update['title']);
        $this->assertFalse($update['mandatory']);
        $this->assertSame([6, 4], array_column($update['changes'], 'build_number'));
        // علاماتُ القوائم التي كتبها الكاتب بيده تُنزع، والأسطرُ الفارغة تسقط.
        $this->assertSame(['ثالثاً', 'رابعاً'], $update['changes'][0]['notes']);
        $this->assertSame(['أولاً', 'ثانياً'], $update['changes'][1]['notes']);
    }

    public function test_a_skipped_mandatory_release_makes_the_latest_one_mandatory(): void
    {
        AppRelease::factory()->build(4)->mandatory()->create();
        AppRelease::factory()->build(5)->create();

        $this->getJson('/api/v1/app-updates/check?target=mobile&build=3')
            ->assertJsonPath('update.build_number', 5)
            ->assertJsonPath('update.mandatory', true);

        // ومن تجاوز الإلزاميَّ عُرض عليه ما بعده اختيارياً كما نُشر.
        $this->getJson('/api/v1/app-updates/check?target=mobile&build=4')
            ->assertJsonPath('update.build_number', 5)
            ->assertJsonPath('update.mandatory', false);
    }

    public function test_drafts_future_releases_and_other_targets_are_not_offered(): void
    {
        AppRelease::factory()->build(7)->draft()->create();
        AppRelease::factory()->build(8)->create(['published_at' => now()->addDay()]);
        AppRelease::factory()->build(9)->target(AppTarget::AdminDesktop)->create();

        $this->getJson('/api/v1/app-updates/check?target=mobile&build=1')
            ->assertJsonPath('update', null);

        $this->getJson('/api/v1/app-updates/check?target=admin_desktop&build=1')
            ->assertJsonPath('update.build_number', 9);
    }

    public function test_the_check_records_what_each_device_runs(): void
    {
        $this->getJson('/api/v1/app-updates/check?target=mobile&build=3&version=1.0.0-beta.3&device='.self::DEVICE)->assertOk();
        $this->getJson('/api/v1/app-updates/check?target=mobile&build=5&version=1.0.0-beta.5&device='.self::DEVICE)->assertOk();
        $this->getJson('/api/v1/app-updates/check?target=admin_android&build=5&device='.self::DEVICE)->assertOk();

        $this->assertSame(2, AppInstall::query()->count());
        $this->assertSame(5, AppInstall::query()->where('target', 'mobile')->value('build_number'));
    }

    public function test_the_overview_counts_active_devices_on_the_latest_build(): void
    {
        AppRelease::factory()->build(5)->create();

        foreach ([5, 5, 4] as $index => $build) {
            app(AppUpdateQuery::class)->recordInstall("0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5{$index}", AppTarget::Mobile, $build, null);
        }

        // جهازٌ لم يسأل منذ شهرين ليس نشطاً.
        AppInstall::query()->create([
            'device_uuid' => '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a59', 'target' => 'mobile', 'build_number' => 2,
            'last_checked_at' => now()->subDays(60),
        ]);

        $mobile = app(AppUpdateQuery::class)->overview()['mobile'];

        $this->assertSame(3, $mobile['active']);
        $this->assertSame(2, $mobile['upToDate']);
        $this->assertSame([5, 4], array_column($mobile['builds'], 'build'));
    }

    public function test_the_check_rejects_an_unknown_target(): void
    {
        $this->getJson('/api/v1/app-updates/check?target=teacher&build=1')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('target');
    }

    public function test_an_uploaded_file_downloads_with_its_size_and_hash_and_resumes(): void
    {
        Storage::fake(AppRelease::DISK);

        $release = app(SaveAppRelease::class)->handle(
            ['target' => 'mobile', 'version' => '1.0.0-beta.6', 'build_number' => 6, 'published_at' => now()],
            UploadedFile::fake()->createWithContent('app.apk', str_repeat('nuzuln', 1000)),
        );

        $this->assertSame('nuzuln-mobile-1.0.0-beta.6-b6.apk', $release->file_name);
        $this->assertSame(6000, $release->file_size);
        $this->assertSame(hash('sha256', str_repeat('nuzuln', 1000)), $release->sha256);

        $this->getJson('/api/v1/app-updates/check?target=mobile&build=5')
            ->assertJsonPath('update.size', 6000)
            ->assertJsonPath('update.download_url', null)
            ->assertJsonPath('update.download_path', "app-updates/{$release->uuid}/download");

        $this->get("/api/v1/app-updates/{$release->uuid}/download")
            ->assertOk()
            ->assertHeader('Content-Type', 'application/vnd.android.package-archive');

        $this->get("/api/v1/app-updates/{$release->uuid}/download", ['Range' => 'bytes=3000-'])
            ->assertStatus(206);

        // الاستئنافُ لا يُعدّ تنزيلاً ثانياً.
        $this->assertSame(1, $release->refresh()->downloads);
    }

    public function test_an_external_release_redirects_to_its_link(): void
    {
        $release = AppRelease::factory()->build(6)->create(['external_url' => 'https://downloads.example.com/n.apk']);

        $this->getJson('/api/v1/app-updates/check?target=mobile&build=5')
            ->assertJsonPath('update.download_url', 'https://downloads.example.com/n.apk');

        $this->get("/api/v1/app-updates/{$release->uuid}/download")
            ->assertRedirect('https://downloads.example.com/n.apk');
    }

    public function test_a_draft_cannot_be_downloaded(): void
    {
        $release = AppRelease::factory()->build(6)->draft()->create();

        $this->get("/api/v1/app-updates/{$release->uuid}/download")->assertNotFound();
    }

    public function test_replacing_a_file_with_a_link_deletes_the_old_file(): void
    {
        Storage::fake(AppRelease::DISK);
        $save = app(SaveAppRelease::class);

        $release = $save->handle(
            ['target' => 'mobile', 'version' => '1.0.0', 'build_number' => 7],
            UploadedFile::fake()->createWithContent('app.apk', 'apk'),
        );
        $path = $release->file_path;
        Storage::disk(AppRelease::DISK)->assertExists($path);

        $save->handle(
            ['target' => 'mobile', 'version' => '1.0.0', 'build_number' => 7, 'external_url' => 'https://x.example.com/a.apk'],
            existing: $release,
        );

        Storage::disk(AppRelease::DISK)->assertMissing($path);
        $this->assertNull($release->refresh()->sha256);
    }
}
