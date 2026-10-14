<?php

namespace Tests\Feature\View;

use Illuminate\Support\Facades\Blade;
use Tests\TestCase;

/**
 * مكوّنات المخططات تسلّم ApexCharts (resources/js/charts.js) إعداداً لا رسماً: هنا يُختبر الإعداد.
 */
class ChartComponentsTest extends TestCase
{
    public function test_the_attendance_trend_hands_the_measured_days_to_the_chart(): void
    {
        $html = Blade::render('<x-attendance-trend :points="$points" />', ['points' => collect([
            ['date' => '2026-10-12', 'rate' => 87.5, 'sessions' => 3],
            // يومٌ بلا جلسة: لا يُرسم صفراً.
            ['date' => '2026-10-13', 'rate' => 0.0, 'sessions' => 0],
            ['date' => '2026-10-14', 'rate' => 92.0, 'sessions' => 2],
        ])]);

        $config = $this->config($html);

        $this->assertSame('trend', $config['type']);
        $this->assertSame([87.5, null, 92], array_column($config['points'], 'value'));
        $this->assertSame(['12/10', '13/10', '14/10'], array_column($config['points'], 'label'));
        $this->assertSame('3 جلسة', $config['points'][0]['detail']);
        $this->assertStringContainsString('المعدّل 89.8%', $html);
    }

    public function test_the_donut_maps_status_classes_to_brand_colours(): void
    {
        $html = Blade::render('<x-charts.donut label="سجل" :segments="$segments" />', ['segments' => [
            ['label' => 'حاضر', 'value' => 12, 'class' => 'stroke-present'],
            ['label' => 'غائب', 'value' => 3, 'class' => 'stroke-absent'],
        ]]);

        $config = $this->config($html);

        $this->assertSame('donut', $config['type']);
        $this->assertSame(['present', 'absent'], array_column($config['segments'], 'color'));
        $this->assertSame('سجل', $config['totalLabel']);
    }

    public function test_an_empty_chart_says_so_instead_of_drawing(): void
    {
        $html = Blade::render('<x-charts.donut :segments="[]" />');

        $this->assertStringNotContainsString('nzChart', $html);
        $this->assertStringContainsString('لا توجد بيانات', $html);
    }

    /**
     * @return array<string, mixed>
     */
    private function config(string $html): array
    {
        $this->assertMatchesRegularExpression('/x-data="nzChart\((.+?)\)"/s', $html);
        preg_match('/x-data="nzChart\((.+?)\)"/s', $html, $match);

        // ‎@js يكتب JSON.parse('…') أو حرفيّة JSON مباشرة — كلاهما يُقرأ هنا.
        $json = html_entity_decode($match[1], ENT_QUOTES);
        if (preg_match("/^JSON\\.parse\\('(.*)'\\)$/s", $json, $parsed)) {
            $json = json_decode('"'.str_replace('"', '\\"', $parsed[1]).'"');
        }

        return json_decode($json, true, flags: JSON_THROW_ON_ERROR);
    }
}
