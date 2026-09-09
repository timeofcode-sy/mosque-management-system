<?php

namespace Tests\Feature\Api;

use App\Enums\TeacherRole;
use App\Models\CourseCircleTeacher;
use App\Models\Guardian;
use App\Models\User;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class BootstrapTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_bootstrap_returns_institute_course_and_the_teachers_circles(): void
    {
        $courseCircle = $this->makeCourseCircle('حلقة البداية');
        $teacher = $this->actingAsTeacher($this->institute);
        CourseCircleTeacher::create(['course_circle_id' => $courseCircle->id, 'teacher_id' => $teacher->id, 'role' => TeacherRole::Main]);

        $response = $this->getJson('/api/v1/bootstrap');

        $response->assertOk();
        $response->assertJsonPath('institute.uuid', $this->institute->uuid);
        $response->assertJsonPath('course.uuid', $this->course->uuid);
        $this->assertContains($courseCircle->uuid, collect($response->json('circles'))->pluck('uuid')->all());
    }

    /**
     * ✅ م.6.6 — ثوابتُ حساب النقاط تصل في اللقطة.
     *
     * institutes.settings جدولٌ **لا يُزامَن** (SYNC-PROTOCOL.md §7)، والإحصاءُ
     * المشتقُّ يحسبه العميل. فتقريرُ النقاط في الديسكتوب يجمع أعمدةَ الحضور
     * بقيمِ المعهد — ولولا حملُها هنا لَحسبها بافتراضيّات الحزمة، فاختلف الرقمُ
     * المطبوع من الجهاز عن رقم اللوحة في كل معهدٍ عدّل نقاطَه. وهو اختلافٌ
     * **صامت**: لا خطأ يُرمى، ولا يعرف القارئُ أيَّ الرقمين يصدّق.
     */
    public function test_bootstrap_carries_the_institutes_points_settings(): void
    {
        $this->institute->update(['settings' => ['points' => ['attendance' => ['present' => 7, 'late' => 3]]]]);

        $this->actingAsTeacher($this->institute);

        $response = $this->getJson('/api/v1/bootstrap');

        $response->assertOk();
        // والأرقامُ الصحيحة تخرج في JSON بلا كسر (json_encode(7.0) === '7')،
        // ولذلك يقرأ العميلُ `num` لا `double` — [PointsSettings.fromJson].
        $response->assertJsonPath('institute.points.attendance.present', 7);
        $response->assertJsonPath('institute.points.attendance.late', 3);
        // وما لم يضبطه المعهد يعود بافتراضيّ PointsSettings::DEFAULTS لا بصفر:
        // القيمةُ الغائبة «لم تُعدَّل» لا «أُلغيت».
        $response->assertJsonPath('institute.points.attendance.absent', 0);
        $response->assertJsonPath('institute.points.quran_per_15_lines', 10);
    }

    public function test_bootstrap_returns_no_circles_for_a_non_teacher_account(): void
    {
        $user = User::factory()->create();
        Guardian::factory()->create(['institute_id' => $this->institute->id, 'user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('guardian');
        Sanctum::actingAs($user, ['*']);

        $response = $this->getJson('/api/v1/bootstrap');

        $response->assertOk();
        $this->assertSame([], $response->json('circles'));
    }
}
