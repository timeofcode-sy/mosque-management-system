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
        $user = User::factory()->create(['username' => 'teacher2395', 'password' => 'secret-password']);
        Teacher::factory()->create(['institute_id' => $institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);
        $user->assignRole('teacher');

        $response = $this->postJson('/api/v1/auth/login', [
            'username' => 'teacher2395',
            'password' => 'secret-password',
            'device_name' => 'iPhone الأستاذ',
        ]);

        $response->assertOk();
        $response->assertJsonStructure(['token', 'user' => ['id', 'name', 'username', 'email', 'roles']]);
        $this->assertContains('teacher', $response->json('user.roles'));
    }

    public function test_login_fails_with_wrong_password(): void
    {
        User::factory()->create(['username' => 'teacher2395', 'password' => 'secret-password']);

        $response = $this->postJson('/api/v1/auth/login', [
            'username' => 'teacher2395',
            'password' => 'wrong-password',
            'device_name' => 'jest',
        ]);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors('username');
    }

    /**
     * البريد يبقى بديلاً مقبولاً — للإداريّ الذي اعتاده، لا للطالب الذي لا بريد له.
     */
    public function test_an_email_still_works_as_a_login_name(): void
    {
        User::factory()->create([
            'username' => 'admin1000',
            'email' => 'admin@example.test',
            'password' => 'secret-password',
        ]);

        $this->postJson('/api/v1/auth/login', [
            'username' => 'admin@example.test',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->assertOk();
    }

    public function test_a_locked_account_cannot_log_in(): void
    {
        User::factory()->inactive()->create(['username' => 'student1000', 'password' => 'secret-password']);

        $this->postJson('/api/v1/auth/login', [
            'username' => 'student1000',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->assertUnprocessable()->assertJsonValidationErrors('username');
    }

    /**
     * الرمز الصادر قبل الإقفال يسقط عند أول طلب بعده — لا ينتظر انتهاء صلاحيته.
     */
    public function test_locking_an_account_kills_its_existing_token(): void
    {
        $user = User::factory()->create(['username' => 'student1001', 'password' => 'secret-password']);

        $token = $this->postJson('/api/v1/auth/login', [
            'username' => 'student1001',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->json('token');

        $user->forceFill(['is_active' => false])->save();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/auth/me')
            ->assertForbidden();

        $this->assertSame(0, PersonalAccessToken::count());
    }

    public function test_a_valid_token_can_call_me_and_the_token_can_be_revoked_by_logout(): void
    {
        User::factory()->create([
            'username' => 'teacher2395',
            'email' => 'teacher@example.test',
            'password' => 'secret-password',
        ]);

        $login = $this->postJson('/api/v1/auth/login', [
            'username' => 'teacher2395',
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
