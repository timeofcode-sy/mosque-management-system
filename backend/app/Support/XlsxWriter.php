<?php

namespace App\Support;

use RuntimeException;
use ZipArchive;

/**
 * كاتب xlsx للقيم وحدها، نظيرُ XlsxReader: أوراقٌ من اليمين إلى اليسار، سطرُ عناوينٍ عريضٌ مثبَّت،
 * وكلُّ قيمةٍ نصّ — فلا يُسقط Excel الصفرَ من أول الجوال ولا يحوّل التاريخ رقماً.
 */
class XlsxWriter
{
    private const MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

    private const RELATIONSHIPS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

    private const PACKAGE = 'http://schemas.openxmlformats.org/package/2006/relationships';

    /**
     * @param  array<string, list<list<string|int|float|bool|null>>>  $sheets  اسم الورقة ← صفوفها، والأول عناوين
     */
    public static function write(string $path, array $sheets): void
    {
        $zip = new ZipArchive;

        if ($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            throw new RuntimeException("تعذّر إنشاء المصنّف: {$path}");
        }

        $entries = $relations = $overrides = '';
        $index = 0;

        foreach ($sheets as $name => $rows) {
            $index++;
            $zip->addFromString("xl/worksheets/sheet{$index}.xml", self::sheet($rows));
            $entries .= '<sheet name="'.self::escape(mb_substr($name, 0, 31))."\" sheetId=\"{$index}\" r:id=\"rId{$index}\"/>";
            $relations .= "<Relationship Id=\"rId{$index}\" Type=\"".self::RELATIONSHIPS."/worksheet\" Target=\"worksheets/sheet{$index}.xml\"/>";
            $overrides .= "<Override PartName=\"/xl/worksheets/sheet{$index}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>";
        }

        $styles = $index + 1;
        $relations .= "<Relationship Id=\"rId{$styles}\" Type=\"".self::RELATIONSHIPS.'/styles" Target="styles.xml"/>';

        $zip->addFromString('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            .'<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            .'<Default Extension="xml" ContentType="application/xml"/>'
            .'<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            .'<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            .$overrides.'</Types>');
        $zip->addFromString('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<Relationships xmlns="'.self::PACKAGE.'"><Relationship Id="rId1" Type="'.self::RELATIONSHIPS.'/officeDocument" Target="xl/workbook.xml"/></Relationships>');
        $zip->addFromString('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<workbook xmlns="'.self::MAIN.'" xmlns:r="'.self::RELATIONSHIPS."\"><sheets>{$entries}</sheets></workbook>");
        $zip->addFromString('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<Relationships xmlns="'.self::PACKAGE."\">{$relations}</Relationships>");
        // الطراز 1 عريضٌ للعناوين، و2 نصٌّ صريح (@) لبقية الخلايا.
        $zip->addFromString('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<styleSheet xmlns="'.self::MAIN.'">'
            .'<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
            .'<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
            .'<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
            .'<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
            .'<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
            .'<xf numFmtId="49" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1" applyNumberFormat="1"/>'
            .'<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>'
            .'<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
            .'</styleSheet>');

        $zip->close();
    }

    /**
     * @param  list<list<string|int|float|bool|null>>  $rows
     */
    private static function sheet(array $rows): string
    {
        $widths = [];
        $data = '';

        foreach (array_values($rows) as $r => $cells) {
            $data .= '<row r="'.($r + 1).'">';

            foreach (array_values($cells) as $c => $value) {
                $text = match (true) {
                    $value === null => '',
                    is_bool($value) => $value ? 'نعم' : 'لا',
                    default => (string) $value,
                };
                $widths[$c] = max($widths[$c] ?? 10, min(50, mb_strlen($text) + 2));

                if ($text === '') {
                    continue;
                }

                $style = $r === 0 ? 1 : 2;
                $data .= '<c r="'.self::column($c).($r + 1)."\" s=\"{$style}\" t=\"inlineStr\"><is><t xml:space=\"preserve\">"
                    .self::escape($text).'</t></is></c>';
            }

            $data .= '</row>';
        }

        $cols = '';

        foreach ($widths as $c => $width) {
            $cols .= '<col min="'.($c + 1).'" max="'.($c + 1)."\" width=\"{$width}\" customWidth=\"1\"/>";
        }

        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            .'<worksheet xmlns="'.self::MAIN.'">'
            .'<sheetViews><sheetView rightToLeft="1" workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
            .($cols === '' ? '' : "<cols>{$cols}</cols>")
            ."<sheetData>{$data}</sheetData></worksheet>";
    }

    /**
     * 0 ← A، 27 ← AB.
     */
    private static function column(int $index): string
    {
        $letters = '';

        for ($index++; $index > 0; $index = intdiv($index - 1, 26)) {
            $letters = chr(65 + ($index - 1) % 26).$letters;
        }

        return $letters;
    }

    private static function escape(string $text): string
    {
        // محارف التحكّم ممنوعةٌ في XML فتُسقط، وإلا رفض Excel فتحَ الملف كلَّه.
        return htmlspecialchars((string) preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', '', $text), ENT_XML1 | ENT_QUOTES, 'UTF-8');
    }
}
