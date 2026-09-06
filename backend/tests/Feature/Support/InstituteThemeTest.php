<?php

namespace Tests\Feature\Support;

use App\Models\Institute;
use App\Support\InstituteTheme;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * ثلاثة ألوان يُدخلها المعهد ⇒ سلالمُ تدرّجٍ تحكم اللوحة والتقارير والتطبيقات.
 */
class InstituteThemeTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_institute_without_colours_keeps_the_design_token_palette(): void
    {
        $theme = InstituteTheme::for(Institute::factory()->create(['settings' => null]));

        $this->assertSame(InstituteTheme::DEFAULTS, $theme->toArray());
        $this->assertTrue($theme->isDefault());
    }

    public function test_the_three_colours_land_on_the_base_step_of_each_scale(): void
    {
        $theme = InstituteTheme::fromArray([
            'primary' => '#7D0A0A',
            'secondary' => '#FFBF9B',
            'surface' => '#EAD196',
        ]);

        $css = $theme->cssVariables();

        // الدرجات الأساسية هي التي تستعملها اللوحة أكثر من غيرها، فتساوي المُدخَل حرفياً.
        $this->assertStringContainsString('--color-brand-600:#7d0a0a', $css);
        $this->assertStringContainsString('--color-gold-500:#ffbf9b', $css);
        $this->assertStringContainsString('--color-sand-100:#ead196', $css);

        $this->assertFalse($theme->isDefault());
    }

    public function test_lighter_steps_move_towards_white_and_darker_ones_towards_black(): void
    {
        $this->assertSame('#ffffff', InstituteTheme::shade('#7d0a0a', 1.0));
        $this->assertSame('#000000', InstituteTheme::shade('#7d0a0a', -1.0));
        $this->assertSame('#7d0a0a', InstituteTheme::shade('#7d0a0a', 0.0));
    }

    public function test_a_malformed_colour_falls_back_instead_of_reaching_the_style_tag(): void
    {
        $theme = InstituteTheme::fromArray([
            'primary' => '</style><script>alert(1)</script>',
            'secondary' => '#abc',
            'surface' => 'not-a-colour',
        ]);

        $this->assertSame(InstituteTheme::DEFAULTS['primary'], $theme->toArray()['primary']);
        $this->assertSame('#aabbcc', $theme->toArray()['secondary']);
        $this->assertSame(InstituteTheme::DEFAULTS['surface'], $theme->toArray()['surface']);
        $this->assertStringNotContainsString('<script>', $theme->cssVariables());
    }

    public function test_every_scale_step_the_panel_uses_is_emitted(): void
    {
        $css = InstituteTheme::fromArray(['primary' => '#7D0A0A'])->cssVariables();

        // تركُ درجةٍ بلا قيمة يخلط لوحتين في شاشة واحدة: Tailwind يولّد صنفاً لكل درجة
        // وهي منثورة في شاشات اللوحة، فما لا يُعاد تعريفه يبقى على اللون القديم.
        foreach ([50, 100, 200, 300, 400, 500, 600, 700, 800, 900] as $step) {
            $this->assertStringContainsString("--color-brand-{$step}:#", $css);
        }

        foreach ([300, 400, 500, 600, 700] as $step) {
            $this->assertStringContainsString("--color-gold-{$step}:#", $css);
        }

        foreach ([50, 100, 200, 300] as $step) {
            $this->assertStringContainsString("--color-sand-{$step}:#", $css);
        }
    }
}
