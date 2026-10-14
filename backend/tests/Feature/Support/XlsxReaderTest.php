<?php

namespace Tests\Feature\Support;

use App\Support\XlsxReader;
use Tests\Concerns\WritesXlsx;
use Tests\TestCase;

class XlsxReaderTest extends TestCase
{
    use WritesXlsx;

    public function test_it_reads_every_sheet_by_name_as_full_width_rows(): void
    {
        $path = $this->writeXlsx([
            'الطلاب' => [
                ['الاسم', 'الجوال', 'المواليد'],
                ['جابر', null, 2013],
                // سطرٌ فارغ في الوسط يبقى سطراً، فتبقى أرقام السطور كما في Excel.
                [],
                ['حمزة', '0951320273', 41401.0],
            ],
            'الأساتذة' => [['الاسم'], ['يوسف البري']],
        ]);

        $sheets = XlsxReader::read($path);

        $this->assertSame(['الطلاب', 'الأساتذة'], array_keys($sheets));
        $this->assertSame([
            ['الاسم', 'الجوال', 'المواليد'],
            ['جابر', null, '2013'],
            [null, null, null],
            ['حمزة', '0951320273', '41401'],
        ], $sheets['الطلاب']);
        $this->assertSame([['الاسم'], ['يوسف البري']], $sheets['الأساتذة']);
    }
}
