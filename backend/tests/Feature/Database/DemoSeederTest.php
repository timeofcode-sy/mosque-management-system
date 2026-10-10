<?php

namespace Tests\Feature\Database;

use App\Models\User;
use Database\Seeders\DemoInstituteSeeder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `php artisan migrate --seed` على قاعدةٍ مبذورة سقط بخرق UNIQUE على username؛ والبذرُ المعهدَ التجريبي
 * يجب أن يكون آمناً على التكرار.
 */
class DemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_seeding_the_demo_institute_twice_is_harmless(): void
    {
        $this->seed(RolesAndPermissionsSeeder::class);
        $this->seed(DemoInstituteSeeder::class);

        $users = User::count();
        $this->assertTrue(User::where('username', 'admin1000')->exists());

        $this->seed(DemoInstituteSeeder::class);

        $this->assertSame($users, User::count());
    }
}
