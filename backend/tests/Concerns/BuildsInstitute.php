<?php

namespace Tests\Concerns;

use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\ShiftDay;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Support\Facades\App;
use Spatie\Permission\PermissionRegistrar;

/**
 * معهد صغير جاهز لاختبار شاشات اللوحة: دورة جارية، دوام بيومين، وحلقتان.
 */
trait BuildsInstitute
{
    protected Institute $institute;

    protected Course $course;

    protected Shift $shift;

    protected User $admin;

    protected function buildInstitute(): void
    {
        $this->institute = Institute::factory()->create();
        $this->course = Course::factory()->current()->create(['institute_id' => $this->institute->id]);
        $this->shift = Shift::factory()->create(['course_id' => $this->course->id]);

        ShiftDay::factory()->create(['shift_id' => $this->shift->id, 'weekday' => 0]);
        ShiftDay::factory()->create(['shift_id' => $this->shift->id, 'weekday' => 2]);

        $this->admin = User::factory()->create();

        // اللوحة تُدار بحساب مشرف حقيقي، فالصلاحيات (attendance.lock/amend) جزء من الحالة المختبَرة.
        $this->seed(RolesAndPermissionsSeeder::class);
        $this->assignRole($this->admin, 'admin');

        $this->actingAs($this->admin);
        $this->withSession(['institute_id' => $this->institute->id]);
    }

    /**
     * إسناد دور ضمن نطاق المعهد — أدوار Spatie هنا مرتبطة بفريق (institute_id).
     */
    protected function assignRole(User $user, string $role): void
    {
        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);

        $user->assignRole($role);
    }

    protected function makeCourseCircle(?string $name = null): CourseCircle
    {
        $courseCircle = CourseCircle::factory()->create([
            'course_id' => $this->course->id,
            'shift_id' => $this->shift->id,
        ]);

        if ($name !== null) {
            $courseCircle->circle->update(['name' => $name]);
        }

        return $courseCircle;
    }
}
