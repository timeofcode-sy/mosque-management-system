<?php

namespace App\Console\Commands;

use App\Models\Institute;
use App\Queries\InstituteWorkbookQuery;
use App\Support\XlsxWriter;
use Illuminate\Console\Command;

/**
 * بيانات معهدٍ في مصنّف xlsx بأوراق مصنّف الاستيراد — نسخةٌ تُقرأ وتُعاد إلى institute:import.
 */
class ExportInstituteCommand extends Command
{
    protected $signature = 'institute:export
                            {institute : معرّف المعهد أو اسمه}
                            {file : مسار المصنّف الناتج (xlsx)}';

    protected $description = 'يصدّر بيانات معهد (الدوامات والأساتذة والحلقات والطلاب وأولياؤهم والحسابات) في مصنّف';

    public function handle(InstituteWorkbookQuery $query): int
    {
        $value = (string) $this->argument('institute');
        $institute = Institute::query()->whereKey(ctype_digit($value) ? (int) $value : 0)->orWhere('name', $value)->first();

        if ($institute === null) {
            $this->error("لا معهد: {$value}");

            return self::FAILURE;
        }

        $sheets = $query->sheets($institute);
        XlsxWriter::write((string) $this->argument('file'), $sheets);

        foreach ($sheets as $name => $rows) {
            $this->line(str_pad((string) (count($rows) - 1), 5, ' ', STR_PAD_LEFT)."  {$name}");
        }

        $this->info("كُتب: {$this->argument('file')}");

        return self::SUCCESS;
    }
}
