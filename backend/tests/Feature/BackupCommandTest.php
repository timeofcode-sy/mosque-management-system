<?php

namespace Tests\Feature;

use App\Models\Institute;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\File;
use PDO;
use Tests\TestCase;
use ZipArchive;

/**
 * النسخُ الاحتياطي — ✅ م.9.2.
 *
 * 🔑 **وحارسُها أن تُفتَح لا أن تُكتَب.** أن يخرج ملفٌّ بحجمٍ معقول لا يقول
 * شيئاً: أشيعُ أعطاب النسخ أن تُكتب كلَّ ليلةٍ بلا شكوى ثم لا تُقرأ يومَ الحاجة.
 * فهذه الاختباراتُ تفتح الأرشيفَ وتستخرج القاعدةَ **وتستعلم منها**.
 */
class BackupCommandTest extends TestCase
{
    /**
     * 🔑 **`DatabaseMigrations` لا `RefreshDatabase`** — والسببُ حقيقةٌ في sqlite
     * لا اصطلاحٌ في الاختبار: `VACUUM` **لا يعمل داخل معاملة**، و`RefreshDatabase`
     * يفتح معاملةً حول كلِّ اختبارٍ ولا يغلقها إلا بعده. فالأمرُ يعمل على الخادم
     * ويسقط ههنا وحدَه.
     *
     * وهو أبطأ (هجرةٌ كاملة لكلِّ اختبار)، لكنّ البديلَ أن يُختبر شيءٌ غيرُ الذي
     * يعمل في الإنتاج.
     */
    use DatabaseMigrations;

    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();

        $this->directory = storage_path('framework/testing/backups-'.uniqid());
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->directory);

        parent::tearDown();
    }

    /**
     * 🔑 الحارسُ الأوّل: **الصفُّ يعود من الأرشيف**.
     *
     * تُفتح النسخةُ وتُستخرج القاعدةُ ويُستعلَم عن معهدٍ كُتب قبل النسخ — فلو
     * خرجت اللقطةُ فارغةً أو ممزّقة لسقط الاختبارُ ههنا لا يومَ الحاجة.
     */
    public function test_the_archive_holds_a_database_that_still_answers(): void
    {
        Institute::factory()->create(['name' => 'معهد عمر الفاروق']);

        $this->artisan('mousqe:backup', ['--path' => $this->directory])->assertSuccessful();

        $archive = $this->onlyArchive();
        $zip = new ZipArchive;
        $this->assertTrue($zip->open($archive) === true, 'الأرشيفُ لا يُفتَح.');

        $extracted = $this->directory.'/restored.sqlite';
        file_put_contents($extracted, $zip->getFromName('database.sqlite'));
        $zip->close();

        $restored = new PDO('sqlite:'.$extracted);
        $name = $restored->query('SELECT name FROM institutes LIMIT 1')?->fetchColumn();

        $this->assertSame('معهد عمر الفاروق', $name);
    }

    /**
     * 🔑 **الشعارُ يُنسخ مع القاعدة.** الرفعُ يسكن القرصَ ولا يبقى في القاعدة
     * إلا مسارُه، فنسخةٌ للقاعدة وحدها تُعيد نظاماً يشير إلى ما لا وجود له —
     * ورابطُ الشعار المكسور لا يُسقط اختباراً ولا يرفع خطأً.
     */
    public function test_the_uploaded_files_travel_with_the_database(): void
    {
        $uploads = storage_path('app/public/institutes');
        File::ensureDirectoryExists($uploads);
        $logo = $uploads.'/backup-test-logo.png';
        file_put_contents($logo, 'PNG');

        try {
            $this->artisan('mousqe:backup', ['--path' => $this->directory])->assertSuccessful();

            $zip = new ZipArchive;
            $zip->open($this->onlyArchive());
            $stored = $zip->getFromName('uploads/institutes/backup-test-logo.png');
            $zip->close();

            $this->assertSame('PNG', $stored);
        } finally {
            @unlink($logo);
        }
    }

    /**
     * 🔑 **ومفتاحُ Firebase لا يسافر معها.** النسخةُ تُنقل خارج الخادم بطبيعتها،
     * فسرٌّ فيها يسكن كلَّ ليلةٍ موضعاً جديداً. والمفتاحُ يُستبدَل من لوحة
     * Firebase في دقيقة، والشعارُ لا يُستبدَل — فيُنسخ ما لا يُستعاض عنه.
     */
    public function test_the_private_directory_is_not_in_the_archive(): void
    {
        $private = storage_path('app/private');
        File::ensureDirectoryExists($private);
        $secret = $private.'/backup-test-credentials.json';
        file_put_contents($secret, '{"private_key":"سرّ"}');

        try {
            $this->artisan('mousqe:backup', ['--path' => $this->directory])->assertSuccessful();

            $zip = new ZipArchive;
            $zip->open($this->onlyArchive());
            $names = [];
            for ($i = 0; $i < $zip->numFiles; $i++) {
                $names[] = $zip->getNameIndex($i);
            }
            $zip->close();

            $this->assertNotContains('uploads/backup-test-credentials.json', $names);
            $this->assertEmpty(preg_grep('/credentials/', $names));
        } finally {
            @unlink($secret);
        }
    }

    /**
     * القديمُ يُحذف والحديثُ يبقى — وإلّا امتلأ القرصُ صمتاً.
     */
    public function test_archives_older_than_the_retention_window_are_pruned(): void
    {
        File::ensureDirectoryExists($this->directory);

        $old = $this->directory.'/mousqe-2020-01-01_020000.zip';
        file_put_contents($old, 'قديمة');
        touch($old, now()->subDays(30)->getTimestamp());

        $recent = $this->directory.'/mousqe-2026-09-09_020000.zip';
        file_put_contents($recent, 'حديثة');
        touch($recent, now()->subDays(2)->getTimestamp());

        $this->artisan('mousqe:backup', ['--path' => $this->directory, '--keep' => 14])
            ->assertSuccessful();

        $this->assertFileDoesNotExist($old);
        $this->assertFileExists($recent);
    }

    /**
     * 🔑 **والفشلُ لا يترك نصفَ نسخة.** أرشيفٌ ممزّقٌ باقٍ في المجلَّد يُقرأ غداً
     * نسخةَ أمسٍ صالحة — وهو أسوأُ من غياب النسخة، لأنه يُطمئن كاذباً.
     */
    public function test_an_unsupported_driver_fails_loudly_and_leaves_nothing_behind(): void
    {
        $original = config('database.default');

        try {
            config([
                'database.connections.imaginary' => ['driver' => 'imaginary-engine', 'database' => ':memory:'],
                'database.default' => 'imaginary',
            ]);

            $this->artisan('mousqe:backup', ['--path' => $this->directory])->assertFailed();

            $this->assertEmpty(glob($this->directory.'/mousqe-*.zip') ?: []);
        } finally {
            // يُعاد قبل الهدم: تفكيكُ الهجرات يحتاج اتصالاً حقيقياً.
            config(['database.default' => $original]);
        }
    }

    private function onlyArchive(): string
    {
        $found = glob($this->directory.'/mousqe-*.zip') ?: [];
        $this->assertCount(1, $found, 'يُنتظر أرشيفٌ واحد.');

        return $found[0];
    }
}
