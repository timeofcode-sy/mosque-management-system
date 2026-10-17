<?php

namespace Tests\Concerns;

use ZipArchive;

/**
 * يكتب مصنّف xlsx حقيقياً من مصفوفات — بأقلّ ما يفتحه Excel ويقرؤه XlsxReader.
 *
 * النصوص في sharedStrings (كما يكتبها Excel) والأرقام قيمٌ عددية، والخلية null تُترك
 * غائبة كما يفعل Excel بالخلايا الفارغة.
 */
trait WritesXlsx
{
    /**
     * @param  array<string, list<list<string|int|float|null>>>  $sheets
     */
    protected function writeXlsx(array $sheets): string
    {
        $path = tempnam(sys_get_temp_dir(), 'xlsx').'.xlsx';
        $zip = new ZipArchive;
        $zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE);

        $main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
        $rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
        $strings = [];
        $entries = '';
        $relations = '';
        $index = 0;

        foreach ($sheets as $name => $rows) {
            $index++;
            $xml = '';

            foreach ($rows as $r => $cells) {
                $xml .= '<row r="'.($r + 1).'">';

                foreach ($cells as $c => $value) {
                    if ($value === null) {
                        continue;
                    }

                    $reference = chr(65 + $c).($r + 1);

                    if (is_int($value) || is_float($value)) {
                        $xml .= "<c r=\"{$reference}\"><v>{$value}</v></c>";

                        continue;
                    }

                    $strings[$value] ??= count($strings);
                    $xml .= "<c r=\"{$reference}\" t=\"s\"><v>{$strings[$value]}</v></c>";
                }

                $xml .= '</row>';
            }

            $zip->addFromString("xl/worksheets/sheet{$index}.xml", "<worksheet xmlns=\"{$main}\"><sheetData>{$xml}</sheetData></worksheet>");
            $entries .= '<sheet name="'.htmlspecialchars($name)."\" sheetId=\"{$index}\" r:id=\"rId{$index}\"/>";
            $relations .= "<Relationship Id=\"rId{$index}\" Type=\"{$rel}/worksheet\" Target=\"worksheets/sheet{$index}.xml\"/>";
        }

        $shared = implode('', array_map(fn (string $text) => '<si><t>'.htmlspecialchars($text).'</t></si>', array_keys($strings)));

        $zip->addFromString('xl/workbook.xml', "<workbook xmlns=\"{$main}\" xmlns:r=\"{$rel}\"><sheets>{$entries}</sheets></workbook>");
        $zip->addFromString('xl/_rels/workbook.xml.rels', "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">{$relations}</Relationships>");
        $zip->addFromString('xl/sharedStrings.xml', "<sst xmlns=\"{$main}\">{$shared}</sst>");
        $zip->close();

        return $path;
    }
}
