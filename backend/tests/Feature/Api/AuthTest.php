<?php

namespace Tests\Feature\Api;

use App\Models\Institute;
use App\Models\Teacher;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\PersonalAccessToken;
use Spatie\Permission\PermissionRegistrar;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_a_teacher_can_log_in_with_correct_credentials_and_receive_a_token(): void
    {
        $institute = Institute::factory()->create();
        $user = User::factory()->create(['email' => 'teacher@example.test', 'password' => 'secret-password']);
        Teacher::factory()->create(['institute_id' => $institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);
        $user->assignRole('teacher');

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'teacher@example.test',
            'password' => 'secret-password',
            'device_name' => 'iPhone الأستاذ',
        ]);

        $response->assertOk();
        $response->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'roles']]);
        $this->assertContains('teacher', $response->json('user.roles'));
    }

    public function test_login_fails_with_wrong_password(): void
    {
        User::factory()->create(['email' => 'teacher@example.test', 'password' => 'secret-password']);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'teacher@example.test',
            'password' => 'wrong-password',
            'device_name' => 'jest',
        ]);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors('email');
    }

    public function test_a_valid_token_can_call_me_and_the_token_can_be_revoked_by_logout(): void
    {
        $user = User::factory()->create(['email' => 'teacher@example.test', 'password' => 'secret-password']);

        $login = $this->postJson('/api/v1/auth/login', [
            'email' => 'teacher@example.test',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->json();

        $token = $login['token'];

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonFragment(['email' => 'teacher@example.test']);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/auth/logout')
            ->assertOk();

        $this->assertSame(0, PersonalAccessToken::count());
    }

    public function test_a_request_without_a_token_is_rejected(): void
    {
        $this->getJson('/api/v1/auth/me')->assertUnauthorized();
    }
}
