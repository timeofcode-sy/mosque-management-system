<?php

namespace Tests\Feature\Models;

use App\Enums\GuardianRelation;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Student;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class GuardianTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_full_name_is_composed_from_the_name_and_the_family_name(): void
    {
        $guardian = Guardian::factory()->create(['first_name' => ' هنادي ', 'family_name' => 'الشيخ  حسن']);

        $this->assertSame('هنادي', $guardian->first_name);
        $this->assertSame('الشيخ حسن', $guardian->family_name);
        $this->assertSame('هنادي الشيخ حسن', $guardian->full_name);
    }

    public function test_a_full_name_written_alone_is_split_at_the_first_space(): void
    {
        $guardian = Guardian::factory()->create(['full_name' => 'رغدة الشيخ قويدر']);

        $this->assertSame('رغدة', $guardian->first_name);
        $this->assertSame('الشيخ قويدر', $guardian->family_name);

        $guardian->update(['full_name' => 'منى']);

        $this->assertSame('منى', $guardian->first_name);
        $this->assertNull($guardian->family_name);
    }

    public function test_changing_the_family_name_alone_renames_the_guardian(): void
    {
        $guardian = Guardian::factory()->create(['first_name' => 'عبير', 'family_name' => 'شولح']);

        $guardian->update(['family_name' => 'عثمان']);

        $this->assertSame('عبير عثمان', $guardian->refresh()->full_name);
    }

    public function test_the_migration_splits_the_names_already_saved(): void
    {
        $student = Student::factory()->create(['father_name' => 'محمد سعيد', 'family_name' => 'الشيخ حسن']);
        $father = Guardian::factory()->create(['institute_id' => $student->institute_id, 'full_name' => 'محمد سعيد الشيخ حسن']);
        $mother = Guardian::factory()->create(['institute_id' => $student->institute_id, 'full_name' => 'منى  عبد الرزاق']);

        GuardianStudent::create(['guardian_id' => $father->id, 'student_id' => $student->id, 'relation' => GuardianRelation::Father]);
        GuardianStudent::create(['guardian_id' => $mother->id, 'student_id' => $student->id, 'relation' => GuardianRelation::Mother]);

        DB::table('guardians')->update(['first_name' => null, 'family_name' => null]);

        $migration = require database_path('migrations/2026_10_14_120000_split_guardian_names.php');
        $migration->down();
        $migration->up();

        // الأب يأخذ قسميه من الطالب لا من أول فراغ، فلا يصير «محمد» اسمَه و«سعيد الشيخ حسن» كنيتَه.
        $this->assertSame(['محمد سعيد', 'الشيخ حسن'], [$father->refresh()->first_name, $father->family_name]);
        $this->assertSame(['منى', 'عبد الرزاق'], [$mother->refresh()->first_name, $mother->family_name]);
    }
}
