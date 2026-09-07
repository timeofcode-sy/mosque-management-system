<?php

namespace Tests\Feature\Authorization;

use App\Models\Student;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * الاختبار الأهمّ في هذه المرحلة: لوحة الويب كانت كلها خلف ['auth', 'verified'] فقط،
 * فأيّ حساب موثَّق — ولو كان طالباً أو ولي أمر — يفتح /institute و/students وكل
 * التقارير. الـ API كان محميّاً واللوحة لم تكن.
 *
 * لكل مسار هنا: الدور المسموح يصل، والممنوع يُرفض بـ 403.
 */
class PanelAccessTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    /**
     * @return array<string, array{0: string, 1: array<int, string>}>
     */
    public static function routeMatrix(): array
    {
        return [
            'بيانات المعهد' => ['institute.edit', ['admin', 'super_admin', 'developer']],
            'الواصفات المخصّصة' => ['custom-fields.index', ['admin', 'super_admin', 'developer']],
            'الدورات' => ['courses.index', ['admin', 'super_admin', 'developer']],
            'الحلقات' => ['circles.index', ['admin', 'super_admin', 'developer']],
            'الطلاب' => ['students.index', ['admin', 'supervisor', 'super_admin', 'developer']],
            'الأساتذة' => ['teachers.index', ['admin', 'super_admin', 'developer']],
            'المناهج' => ['curricula.index', ['admin', 'super_admin', 'developer']],
            'التفقّد' => ['attendance.index', ['admin', 'supervisor', 'teacher', 'super_admin', 'developer']],
            'أذونات الغياب' => ['excuses.index', ['admin', 'supervisor', 'teacher', 'super_admin', 'developer']],
            /** ولي الأمر يحمل reports.view في كتالوج الأدوار منذ المرحلة الأولى — انظر §التقارير في نقطة التفتيش */
            'التقارير' => ['reports.index', ['admin', 'supervisor', 'teacher', 'guardian', 'super_admin', 'developer']],
            'الإحصائيات' => ['stats.index', ['admin', 'supervisor', 'teacher', 'guardian', 'super_admin', 'developer']],
            'المعاهد' => ['institutes.index', ['super_admin', 'developer']],
            'لوحة المعاهد' => ['institutes.overview', ['super_admin', 'developer']],
            'المستخدمون' => ['users.index', ['admin', 'super_admin', 'developer']],
            /** 🔄 2026-09-07: خرجت من أدوات المبرمج إلى conflicts.review — يملكها المشرف ومدير المعهد */
            'تعارضات المزامنة' => ['system.conflicts', ['admin', 'supervisor', 'super_admin', 'developer']],
            'الأجهزة' => ['system.devices', ['developer']],
            'سجل التغييرات' => ['system.change-log', ['developer']],
        ];
    }

    /**
     * @param  array<int, string>  $allowed
     */
    #[DataProvider('routeMatrix')]
    public function test_each_panel_route_admits_only_its_roles(string $routeName, array $allowed): void
    {
        foreach (['admin', 'supervisor', 'teacher', 'guardian', 'student', 'super_admin', 'developer'] as $role) {
            $this->actAsRole($role);

            $expected = in_array($role, $allowed, true) ? 200 : 403;

            $this->get(route($routeName))->assertStatus($expected);
        }
    }

    public function test_the_dashboard_stays_open_to_every_authenticated_user(): void
    {
        foreach (['guardian', 'student'] as $role) {
            $this->actAsRole($role);

            $this->get(route('dashboard'))->assertOk();
        }
    }

    /**
     * الحالة التي كانت تفشل قبل هذه المرحلة: الطالب يفتح إعدادات المعهد وقائمة الطلاب.
     */
    public function test_a_student_is_locked_out_of_the_management_screens(): void
    {
        $this->actAsRole('student');

        $this->get(route('institute.edit'))->assertForbidden();
        $this->get(route('custom-fields.index'))->assertForbidden();
        $this->get(route('students.index'))->assertForbidden();
        $this->get(route('attendance.index'))->assertForbidden();
    }

    public function test_a_guardian_cannot_reach_the_student_records(): void
    {
        $this->actAsRole('guardian');

        $this->get(route('students.index'))->assertForbidden();
        $this->get(route('teachers.index'))->assertForbidden();
        $this->get(route('attendance.index'))->assertForbidden();
    }

    /**
     * المبرمج يصل إلى كل شيء عبر Gate::before رغم أن دوره مسنَد خارج كل معهد،
     * فلا يراه فحصُ spatie المقيَّد بالمعهد الحالي.
     */
    public function test_a_developer_reaches_everything_through_the_global_gate(): void
    {
        $this->actAsRole('developer');

        foreach (array_column(self::routeMatrix(), 0) as $routeName) {
            $this->get(route($routeName))->assertOk();
        }
    }

    public function test_print_routes_are_behind_the_reports_permission(): void
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $this->actAsRole('teacher');
        $this->get(route('reports.print.student', $student))->assertOk();

        $this->actAsRole('student');
        $this->get(route('reports.print.student', $student))->assertForbidden();
    }

    public function test_guests_are_still_redirected_to_login(): void
    {
        auth()->logout();

        $this->get(route('institutes.index'))->assertRedirect(route('login'));
    }

    /**
     * يبني مستخدماً بالدور المطلوب ويجعله الفاعل: الأدوار العابرة تُسنَد خارج المعاهد،
     * والباقي داخل معهد الاختبار.
     */
    private function actAsRole(string $role): void
    {
        $user = User::factory()->create();

        if (in_array($role, User::GLOBAL_ROLES, true)) {
            $user->assignGlobalRole($role);
        } else {
            $this->assignRole($user, $role);
        }

        $this->actingAs($user);
        $this->withSession(['institute_id' => $this->institute->id]);
    }
}
