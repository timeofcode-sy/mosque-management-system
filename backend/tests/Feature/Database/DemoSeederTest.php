<?php

namespace Tests\Feature\Database;

use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\User;
use Database\Seeders\CurriculumSeeder;
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

    public function test_the_demo_institute_is_omar_al_farouq_with_real_recitation_ranges(): void
    {
        $this->seed(RolesAndPermissionsSeeder::class);
        $this->seed(CurriculumSeeder::class);
        $this->seed(DemoInstituteSeeder::class);

        $institute = Institute::firstOrFail();

        $this->assertSame('معهد عمر الفاروق', $institute->name);
        $this->assertSame('ريف دمشق - عربين', $institute->address);
        $this->assertSame('+963935650325', $institute->phone);

        // كل تسميعٍ بمدى سورٍ وآيات، وفي الدورة تسميعٌ سابقٌ بلا حصة.
        $this->assertSame(0, MemorizationLog::whereNull('from_surah')->count());
        $this->assertGreaterThan(0, MemorizationLog::whereNull('attendance_session_id')->count());
        $this->assertSame(0, MemorizationLog::whereColumn('from_surah', 'to_surah')->whereColumn('from_ayah', '>', 'to_ayah')->count());
    }
}
