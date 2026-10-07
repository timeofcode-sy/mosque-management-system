<?php

namespace Tests\Feature\Api;

use App\Models\Institute;
use App\Models\Teacher;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Contracts\Debug\ExceptionHandler;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
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

    /**
     * ✅ م.9.1 — دَينُ م.4 مسدوداً: خمسُ محاولاتٍ خاطئة تقفل الاسمَ ربعَ ساعة.
     *
     * والسادسةُ تُردّ **قبل أن تُفحص كلمةُ المرور أصلاً** — فالكلمةُ الصحيحة
     * نفسُها لا تفتح خلال القفل، وإلّا كان القفلُ زينةً.
     */
    public function test_five_wrong_passwords_lock_the_account_for_this_address(): void
    {
        User::factory()->create(['username' => 'student1000', 'password' => 'secret-password']);

        foreach (range(1, 5) as $attempt) {
            $this->postJson('/api/v1/auth/login', [
                'username' => 'student1000',
                'password' => 'wrong-password',
                'device_name' => 'jest',
            ])->assertUnprocessable();
        }

        $locked = $this->postJson('/api/v1/auth/login', [
            'username' => 'student1000',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ]);

        $locked->assertStatus(429);
        $this->assertStringContainsString('أعِد المحاولة بعد', $locked->json('errors.username.0'));
        $this->assertSame(0, PersonalAccessToken::count());
    }

    /**
     * 🔑 القفلُ على **الاسم والعنوان معاً**: زميلٌ على الشبكة نفسِها لا يُحرَم
     * لأنّ غيرَه أخطأ. ولولا ذلك لأقفلت شبكةُ المسجد على أربعمئة طالب.
     */
    public function test_locking_one_name_does_not_lock_another_on_the_same_address(): void
    {
        User::factory()->create(['username' => 'student1000', 'password' => 'secret-password']);
        User::factory()->create(['username' => 'student1001', 'password' => 'secret-password']);

        foreach (range(1, 5) as $attempt) {
            $this->postJson('/api/v1/auth/login', [
                'username' => 'student1000',
                'password' => 'wrong-password',
                'device_name' => 'jest',
            ])->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/login', [
            'username' => 'student1001',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->assertOk();
    }

    /**
     * 🔑 **النجاحُ يمسح العدّاد**، فأربعُ محاولاتٍ خاطئة ثم دخولٌ صحيح لا تترك
     * أثراً: من نسي كلمتَه مرّتين هذا الشهر ومرّتين الشهر القادم ليس مهاجماً.
     */
    public function test_a_successful_login_clears_the_failed_attempts(): void
    {
        User::factory()->create(['username' => 'student1000', 'password' => 'secret-password']);

        foreach (range(1, 4) as $attempt) {
            $this->postJson('/api/v1/auth/login', [
                'username' => 'student1000',
                'password' => 'wrong-password',
                'device_name' => 'jest',
            ])->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/login', [
            'username' => 'student1000',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->assertOk();

        // العدّادُ ممسوحٌ الآن، فأربعٌ أخرى لا تبلغ الحدّ.
        foreach (range(1, 4) as $attempt) {
            $this->postJson('/api/v1/auth/login', [
                'username' => 'student1000',
                'password' => 'wrong-password',
                'device_name' => 'jest',
            ])->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/login', [
            'username' => 'student1000',
            'password' => 'secret-password',
            'device_name' => 'jest',
        ])->assertOk();
    }

    /**
     * 🔑 **رسالةُ 429 عربيةٌ** أيّاً كان مصدرُها: العميلُ يعرض نصَّ الخادم كما
     * هو (`messageFor`)، فنصُّ لارافيل الإنجليزي كان يبلغ شاشةَ أبٍ لا يقرؤه.
     */
    public function test_the_outer_ceiling_answers_in_arabic(): void
    {
        $exception = new ThrottleRequestsException('Too Many Attempts.');

        $rendered = app(ExceptionHandler::class)->render(
            Request::create('/api/v1/auth/login', 'POST'),
            $exception,
        );

        $body = json_decode($rendered->getContent(), true);

        $this->assertSame(429, $rendered->getStatusCode());
        $this->assertStringContainsString('حاولتَ مراراً', $body['message']);
        $this->assertStringNotContainsString('Too Many Attempts', $body['message']);
    }
}
