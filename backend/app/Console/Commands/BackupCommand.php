<?php

namespace App\Console\Commands;

use FilesystemIterator;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use PDO;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RuntimeException;
use Symfony\Component\Process\Process;
use ZipArchive;

/**
 * نسخةٌ احتياطية واحدة: القاعدةُ ورفوعاتُ المعهد في أرشيفٍ موقَّت — ✅ م.9.2.
 *
 * ## 1. لماذا الرفوعاتُ معها ولم تكفِ القاعدة؟
 *
 * شعارُ المعهد يُرفع إلى `storage/app/public/institutes/`، ولا يبقى في القاعدة
 * إلا `institutes.logo_path` — أي **اسمُ ملفٍّ لا الملفّ**. فنسخةٌ للقاعدة وحدها
 * تُعيد نظاماً يشير إلى ما لم يعد موجوداً: `/bootstrap` يعطي التطبيقاتِ الأربعةَ
 * رابطَ شعارٍ مكسور، ولا خطأَ يُرفع ولا اختبارَ يسقط.
 *
 * ## 2. ولماذا `private/` **ليست** معها؟
 *
 * فيها مفتاحُ حساب خدمة Firebase (م.7.4). والنسخةُ الاحتياطية تُنقل خارج الخادم
 * بطبيعتها — قرصٌ آخر، أو بريد، أو تخزينٌ سحابي — فإدراجُ المفتاح فيها يضاعف
 * المواضعَ التي يسكنها سرٌّ **كلَّ ليلة**.
 *
 * والفرقُ الفاصل: المفتاحُ يُولَّد من جديد من لوحة Firebase في دقيقة، والشعارُ
 * الذي رفعه المديرُ قبل سنةٍ لا يُستعاد من أحد. **يُنسخ ما لا يُستبدَل.**
 */
class BackupCommand extends Command
{
    protected $signature = 'mousqe:backup
                            {--keep= : كم يوماً تُحفظ النسخ (الافتراضُ من config/backup.php)}
                            {--path= : مجلَّدُ الوجهة}';

    protected $description = 'ينسخ قاعدة البيانات ورفوعات المعهد في أرشيفٍ واحد موقَّت';

    public function handle(): int
    {
        $directory = $this->option('path') ?: config('backup.path');
        $keepDays = (int) ($this->option('keep') ?: config('backup.keep_days'));

        if (! is_dir($directory) && ! mkdir($directory, 0750, true) && ! is_dir($directory)) {
            $this->error("تعذَّر إنشاء مجلَّد النسخ: {$directory}");

            return self::FAILURE;
        }

        $stamp = now()->format('Y-m-d_His');
        $archivePath = rtrim($directory, '/\\').DIRECTORY_SEPARATOR."mousqe-{$stamp}.zip";
        $dumpPath = tempnam(sys_get_temp_dir(), 'mousqe-dump-');

        try {
            $dumpName = $this->dumpDatabase($dumpPath);
            $this->writeArchive($archivePath, $dumpPath, $dumpName);
            $this->verify($archivePath, $dumpName);
        } catch (RuntimeException $exception) {
            // 🔑 الفشلُ يمحو أثرَه: أرشيفٌ نصفُ مكتوبٍ يبقى في المجلَّد يُقرأ غداً
            // نسخةً صالحة، وهو أسوأُ من لا نسخة.
            @unlink($archivePath);
            $this->error($exception->getMessage());

            return self::FAILURE;
        } finally {
            @unlink($dumpPath);
        }

        $this->info('النسخة: '.$archivePath.' ('.$this->humanSize((int) filesize($archivePath)).')');
        $this->pruneOlderThan($directory, $keepDays);

        return self::SUCCESS;
    }

    /**
     * لقطةٌ متّسقة من القاعدة — والطريقةُ تتبع المحرّك.
     *
     * 🔑 **ولا نسخَ ملفٍّ في sqlite.** `copy()` على ملفٍّ تُكتب فيه صفحاتٌ الآن
     * يلتقط نصفَ معاملة، فيخرج ملفٌّ يبدو سليماً ولا يُفتح يومَ الحاجة.
     * و`VACUUM INTO` يكتب لقطةً متّسقة بلا أن يوقف الكتابة — وهي الطريقةُ نفسُها
     * التي اختارها الديسكتوب لنسخته المحلّية في م.6.6.
     *
     * @return string اسمُ الملفّ داخل الأرشيف
     */
    private function dumpDatabase(string $target): string
    {
        $connection = config('database.default');
        $driver = config("database.connections.{$connection}.driver");

        return match ($driver) {
            'sqlite' => $this->dumpSqlite($target),
            'mysql', 'mariadb' => $this->dumpMysql($connection, $target),
            'pgsql' => $this->dumpPostgres($connection, $target),
            default => throw new RuntimeException("محرّكُ قاعدةٍ لا نسخةَ له ههنا: {$driver}"),
        };
    }

    private function dumpSqlite(string $target): string
    {
        // `VACUUM INTO` يرفض ملفاً قائماً، و`tempnam` أنشأه فارغاً.
        @unlink($target);

        DB::statement('VACUUM INTO ?', [$target]);

        if (! is_file($target) || filesize($target) === 0) {
            throw new RuntimeException('خرجت لقطةُ sqlite فارغة.');
        }

        // فحصُ سلامةٍ على اللقطة نفسِها — أرخصُ موضعٍ يُكتشف فيه العطب.
        $integrity = (new PDO('sqlite:'.$target))->query('PRAGMA integrity_check')?->fetchColumn();

        if ($integrity !== 'ok') {
            throw new RuntimeException("لقطةُ sqlite معطوبة: {$integrity}");
        }

        return 'database.sqlite';
    }

    private function dumpMysql(string $connection, string $target): string
    {
        $config = config("database.connections.{$connection}");

        $this->runDump(
            [
                'mysqldump',
                '--host='.$config['host'],
                '--port='.$config['port'],
                '--user='.$config['username'],
                // معاملةٌ واحدة: النسخةُ حالةُ لحظةٍ واحدة لا حالةَ جدولٍ جدولاً،
                // وبلا قفلِ الكتابة على معهدٍ يتفقّد الآن.
                '--single-transaction',
                '--quick',
                '--default-character-set=utf8mb4',
                '--result-file='.$target,
                $config['database'],
            ],
            // 🔑 كلمةُ المرور في البيئة لا في سطر الأوامر: سطرُ الأوامر يقرؤه
            // `ps` كلُّ حسابٍ على الخادم.
            ['MYSQL_PWD' => (string) $config['password']],
        );

        return 'database.sql';
    }

    private function dumpPostgres(string $connection, string $target): string
    {
        $config = config("database.connections.{$connection}");

        $this->runDump(
            [
                'pg_dump',
                '--host='.$config['host'],
                '--port='.$config['port'],
                '--username='.$config['username'],
                '--no-password',
                '--file='.$target,
                $config['database'],
            ],
            ['PGPASSWORD' => (string) $config['password']],
        );

        return 'database.sql';
    }

    /**
     * @param  list<string>  $command
     * @param  array<string, string>  $env
     */
    private function runDump(array $command, array $env): void
    {
        $process = new Process($command, env: $env, timeout: 1800);
        $process->run();

        if (! $process->isSuccessful()) {
            throw new RuntimeException(
                'فشل التفريغ ('.$command[0].'): '.trim($process->getErrorOutput() ?: $process->getOutput()),
            );
        }
    }

    private function writeArchive(string $archivePath, string $dumpPath, string $dumpName): void
    {
        $zip = new ZipArchive;

        if ($zip->open($archivePath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            throw new RuntimeException("تعذَّر فتحُ الأرشيف للكتابة: {$archivePath}");
        }

        $zip->addFile($dumpPath, $dumpName);

        $uploads = storage_path('app/public');

        if (is_dir($uploads)) {
            foreach ($this->filesIn($uploads) as $file) {
                $zip->addFile($file, 'uploads/'.str_replace('\\', '/', substr($file, strlen($uploads) + 1)));
            }
        }

        if (! $zip->close()) {
            throw new RuntimeException('تعذَّر إغلاقُ الأرشيف — لم تُكتب النسخة.');
        }
    }

    /**
     * 🔑 **النسخةُ التي لم تُفتَح ليست نسخة.** أشيعُ أعطاب النسخ الاحتياطي أن
     * تُكتب كلَّ ليلةٍ بلا شكوى ثم لا تُفتَح يومَ الحاجة. فيُعاد فتحُ الأرشيف من
     * القرص بعد إغلاقه، ويُتحقَّق أن التفريغَ فيه وأنه غيرُ فارغ.
     */
    private function verify(string $archivePath, string $dumpName): void
    {
        $zip = new ZipArchive;

        if ($zip->open($archivePath, ZipArchive::RDONLY) !== true) {
            throw new RuntimeException('كُتب الأرشيفُ ولا يُفتَح.');
        }

        $entry = $zip->statName($dumpName);
        $zip->close();

        if ($entry === false || $entry['size'] === 0) {
            throw new RuntimeException("الأرشيفُ بلا تفريغٍ صالح ({$dumpName}).");
        }
    }

    private function pruneOlderThan(string $directory, int $keepDays): void
    {
        if ($keepDays <= 0) {
            return;
        }

        $cutoff = now()->subDays($keepDays)->getTimestamp();
        $removed = 0;

        foreach (glob(rtrim($directory, '/\\').DIRECTORY_SEPARATOR.'mousqe-*.zip') ?: [] as $file) {
            if (filemtime($file) < $cutoff) {
                @unlink($file);
                $removed++;
            }
        }

        if ($removed > 0) {
            $this->line("حُذفت {$removed} نسخةً أقدمَ من {$keepDays} يوماً.");
        }
    }

    /**
     * @return list<string>
     */
    private function filesIn(string $directory): array
    {
        $found = [];

        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS),
        );

        foreach ($iterator as $file) {
            if ($file->isFile()) {
                $found[] = $file->getPathname();
            }
        }

        return $found;
    }

    private function humanSize(int $bytes): string
    {
        return match (true) {
            $bytes >= 1048576 => round($bytes / 1048576, 1).' م.ب',
            $bytes >= 1024 => round($bytes / 1024).' ك.ب',
            default => $bytes.' بايت',
        };
    }
}
