<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * صفحتا «حول نزلاً» و«المطوِّر»: عامّتان، وتحملان ما في config/developer.php — ونظيرُه في
 * تطبيقات فلاتر `mousqe_ui/lib/src/about/developer.dart`.
 */
class AboutPagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_about_page_is_public_and_lists_technical_support(): void
    {
        $response = $this->get(route('about'));

        $response->assertOk()
            ->assertSee('الدعم الفني والتقني')
            ->assertSee(config('developer.name'));

        foreach (config('developer.support') as $person) {
            $digits = preg_replace('/\D/', '', $person['phone']);

            $response->assertSee($person['name'])
                ->assertSee($person['phone'])
                ->assertSee('tel:+'.$digits, false)
                ->assertSee('https://wa.me/'.$digits, false);
        }
    }

    public function test_the_developer_page_is_public_and_lists_every_contact(): void
    {
        $response = $this->get(route('developer'));

        $response->assertOk()
            ->assertSee(config('developer.arabic_name'))
            ->assertSee(config('developer.address'))
            ->assertSee(config('developer.logo'), false);

        foreach (config('developer.contacts') as $contact) {
            $response->assertSee($contact['url'], false)->assertSee($contact['value']);
        }

        foreach (config('developer.services') as $service) {
            $response->assertSee($service);
        }
    }

    public function test_the_home_page_footer_links_both_pages(): void
    {
        $this->get(route('home'))
            ->assertOk()
            ->assertSee(route('about'), false)
            ->assertSee(route('developer'), false);
    }

    public function test_the_panel_footer_links_both_pages(): void
    {
        $this->blade('<x-panel-footer />')
            ->assertSee(route('about'), false)
            ->assertSee(route('developer'), false)
            ->assertSee(config('developer.name'));
    }

    public function test_a_signed_in_user_sees_the_dashboard_button_instead_of_login(): void
    {
        $this->actingAs(User::factory()->create())
            ->get(route('about'))
            ->assertOk()
            ->assertSee('لوحة المعلومات');
    }

    public function test_the_phone_and_whatsapp_contacts_reach_the_same_number(): void
    {
        $contacts = collect(config('developer.contacts'))->keyBy('label');

        $this->assertSame(
            preg_replace('/\D/', '', $contacts['الهاتف']['url']),
            preg_replace('/\D/', '', $contacts['واتساب']['url']),
        );
    }
}
