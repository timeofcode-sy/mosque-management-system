<?php

namespace App\Support;

use RuntimeException;
use SimpleXMLElement;
use ZipArchive;

/**
 * قارئ xlsx للقيم وحدها — بلا تنسيق ولا صيغ — يكفي لمصنّف استيراد.
 *
 * مكتوبٌ هنا لا مكتبةً لأن الحاجة قراءةُ جداول نصّية مرّةً عند ضمّ معهد، و`ext-zip`
 * شرطٌ أصلاً في composer.json. كلُّ قيمةٍ تعود نصّاً: الرقم كما يُكتب (2011 لا 2011.0)،
 * والخلية الفارغة null. التاريخ المخزَّن رقماً تسلسلياً يعود رقماً، ويحوّله المستدعي.
 */
class XlsxReader
{
    private const MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

    private const RELATIONSHIPS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

    private const PACKAGE_RELATIONSHIPS = 'http://schemas.openxmlformats.org/package/2006/relationships';

    /**
     * أوراق المصنّف بأسمائها، وكلُّ ورقةٍ صفوفٌ كاملة العرض (الخلية الغائبة null).
     *
     * @return array<string, list<list<?string>>>
     */
    public static function read(string $path): array
    {
        $zip = new ZipArchive;

        if ($zip->open($path, ZipArchive::RDONLY) !== true) {
            throw new RuntimeException("تعذّر فتح المصنّف: {$path}");
        }

        try {
            $strings = self::sharedStrings($zip);
            $targets = self::sheetTargets($zip);
            $sheets = [];

            foreach ($targets as $name => $target) {
                $sheets[$name] = self::rows(self::xml($zip, $target), $strings);
            }

            return $sheets;
        } finally {
            $zip->close();
        }
    }

    /**
     * @return array<string, string> اسم الورقة إلى مسارها داخل الأرشيف
     */
    private static function sheetTargets(ZipArchive $zip): array
    {
        $relations = [];

        foreach (self::xml($zip, 'xl/_rels/workbook.xml.rels')->children(self::PACKAGE_RELATIONSHIPS) as $relation) {
            $target = ltrim((string) self::attribute($relation, 'Target'), '/');
            $relations[(string) self::attribute($relation, 'Id')] = str_starts_with($target, 'xl/') ? $target : "xl/{$target}";
        }

        $targets = [];

        foreach (self::xml($zip, 'xl/workbook.xml')->children(self::MAIN)->sheets->sheet as $sheet) {
            $id = (string) $sheet->attributes(self::RELATIONSHIPS)['id'];
            $targets[(string) self::attribute($sheet, 'name')] = $relations[$id];
        }

        return $targets;
    }

    /**
     * @return list<string>
     */
    private static function sharedStrings(ZipArchive $zip): array
    {
        if ($zip->locateName('xl/sharedStrings.xml') === false) {
            return [];
        }

        $strings = [];

        foreach (self::xml($zip, 'xl/sharedStrings.xml')->children(self::MAIN)->si as $item) {
            $strings[] = self::text($item);
        }

        return $strings;
    }

    /**
     * @param  list<string>  $strings
     * @return list<list<?string>>
     */
    private static function rows(SimpleXMLElement $sheet, array $strings): array
    {
        $rows = [];
        $width = 0;

        foreach ($sheet->children(self::MAIN)->sheetData->row as $row) {
            $cells = [];

            foreach ($row->children(self::MAIN)->c as $cell) {
                $cells[self::column((string) self::attribute($cell, 'r'))] = self::value($cell, $strings);
            }

            $index = (int) self::attribute($row, 'r') - 1;
            $rows[$index] = $cells;
            $width = max($width, $cells === [] ? 0 : max(array_keys($cells)) + 1);
        }

        if ($rows === []) {
            return [];
        }

        $full = [];

        for ($i = 0; $i <= max(array_keys($rows)); $i++) {
            $full[] = array_replace(array_fill(0, $width, null), $rows[$i] ?? []);
        }

        return $full;
    }

    /**
     * @param  list<string>  $strings
     */
    private static function value(SimpleXMLElement $cell, array $strings): ?string
    {
        $children = $cell->children(self::MAIN);

        $value = match ((string) self::attribute($cell, 't')) {
            's' => $strings[(int) $children->v] ?? null,
            // الخلية النصّية الفارغة تُكتب أحياناً بلا عنصر is.
            'inlineStr' => isset($children->is) ? self::text($children->is) : null,
            'b' => (string) $children->v === '1' ? 'TRUE' : 'FALSE',
            default => isset($children->v) ? (string) $children->v : null,
        };

        if ($value !== null && (string) self::attribute($cell, 't') === '' && is_numeric($value) && (float) $value == (int) $value) {
            $value = (string) (int) $value;
        }

        return $value === '' ? null : $value;
    }

    /**
     * نصُّ عنصرٍ قد يكون بسيطاً (t) أو منسّقاً (r/t) — ويُتجاهل النطقُ الصوتي (rPh).
     */
    private static function text(SimpleXMLElement $item): string
    {
        $children = $item->children(self::MAIN);

        if (isset($children->t)) {
            return (string) $children->t;
        }

        $text = '';

        foreach ($children->r as $run) {
            $text .= (string) $run->children(self::MAIN)->t;
        }

        return $text;
    }

    /**
     * «AB12» ← 27 (من الصفر).
     */
    private static function column(string $reference): int
    {
        $letters = preg_replace('/\d+/', '', $reference);
        $index = 0;

        foreach (str_split($letters) as $letter) {
            $index = $index * 26 + (ord($letter) - 64);
        }

        return $index - 1;
    }

    /**
     * سمةٌ بلا بادئة. العنصر المأخوذ بـ children($namespace) يبحث بـ $element['x'] في
     * ذلك النطاق فلا يجد سماته العادية، فتُقرأ من attributes() صراحةً.
     */
    private static function attribute(SimpleXMLElement $element, string $name): string
    {
        return (string) $element->attributes()[$name];
    }

    private static function xml(ZipArchive $zip, string $path): SimpleXMLElement
    {
        $content = $zip->getFromName($path);

        if ($content === false) {
            throw new RuntimeException("المصنّف ناقص: لا يحوي {$path}");
        }

        return new SimpleXMLElement($content);
    }
}
