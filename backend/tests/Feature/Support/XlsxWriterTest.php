<?php

namespace Tests\Feature\Support;

use App\Support\XlsxReader;
use App\Support\XlsxWriter;
use Tests\TestCase;

class XlsxWriterTest extends TestCase
{
    public function test_what_it_writes_reads_back_as_text(): void
    {
        $path = tempnam(sys_get_temp_dir(), 'xlsx').'.xlsx';

        XlsxWriter::write($path, [
            'الطلاب' => [
                ['الاسم', 'الجوال', 'المواليد', 'ملاحظة'],
                // الصفر في أول الجوال والتاريخ يبقيان نصّاً، والفارغ يبقى فارغاً.
                ['جابر', '0951320273', '2013-05-07', null],
                ['حمزة & أخوه <الأكبر>', null, 2011, true],
            ],
            'فارغة' => [['العنوان']],
        ]);

        $this->assertSame([
            'الطلاب' => [
                ['الاسم', 'الجوال', 'المواليد', 'ملاحظة'],
                ['جابر', '0951320273', '2013-05-07', null],
                ['حمزة & أخوه <الأكبر>', null, '2011', 'نعم'],
            ],
            'فارغة' => [['العنوان']],
        ], XlsxReader::read($path));
    }
}
