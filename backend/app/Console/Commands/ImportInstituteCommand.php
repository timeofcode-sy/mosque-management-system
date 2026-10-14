<?php

namespace App\Console\Commands;

use App\Actions\ImportInstitute;
use App\Support\XlsxReader;
use Illuminate\Console\Command;

/**
 * ضمُّ معهدٍ من مصنّف استيراد (xlsx) — البنية والخطوات في docs/IMPORT.md.
 *
 * يُشغَّل مرّةً بـ--dry-run أولاً: يكتب كلَّ شيء في معاملةٍ ثم يتراجع، فيظهر كلُّ خطأ
 * (حلقةٌ ممتلئة، جزءٌ غير موجود…) قبل أن يُكتب حرفٌ واحد.
 */
class ImportInstituteCommand extends Command
{
    protected $signature = 'institute:import
                            {file : مصنّف الاستيراد (xlsx)}
                            {--dry-run : يتحقّق ويعرض ما سيُكتب ثم يتراجع}
                            {--without-passwords : الحسابات بأسماء دخولها وبلا كلمات حتى تُصدَر (accounts:issue-passwords)}';

    protected $description = 'ينشئ معهداً كاملاً (دورة، دوامات، أساتذة، حلقات، طلاب وأولياؤهم) من مصنّف استيراد';

    public function handle(ImportInstitute $import): int
    {
        $file = (string) $this->argument('file');

        if (! is_file($file)) {
            $this->error("لا ملفَّ في: {$file}");

            return self::FAILURE;
        }

        $dryRun = (bool) $this->option('dry-run');
        $this->info($dryRun ? 'تشغيلٌ جافّ: لن يُحفظ شيء.' : 'يُستورد المعهد…');

        $withoutPasswords = (bool) $this->option('without-passwords');
        $result = $import->handle(XlsxReader::read($file), $dryRun, $withoutPasswords);

        foreach (array_unique($result['warnings']) as $warning) {
            $this->warn("تنبيه: {$warning}");
        }

        if ($result['errors'] !== []) {
            $this->error('لم يُستورد شيء — صحّح المصنّف ثم أعد:');

            foreach ($result['errors'] as $error) {
                $this->line("  • {$error}");
            }

            return self::FAILURE;
        }

        $this->table(['', 'العدد'], collect($result['counts'])->map(fn (int $count, string $label) => [$label, $count])->values()->all());

        if ($dryRun) {
            $this->info('المصنّف سليم. أعد الأمر بلا --dry-run للاستيراد.');

            return self::SUCCESS;
        }

        $this->info("استُورد «{$result['institute']->name}».");
        $this->line('بقي من اللوحة: إسنادُ مشرف المعهد (المستخدمون)، ورفعُ الشعار (إعدادات المعهد)، وتوزيعُ بيانات الدخول (بيانات الدخول).');

        if ($withoutPasswords) {
            $this->line("الحسابات بلا كلمات مرور: تُصدَر حين تشاء بـ php artisan accounts:issue-passwords {$result['institute']->id}");
        }

        return self::SUCCESS;
    }
}
