<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\CourseCircleResource;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\User;
use App\Queries\TeacherCircleQuery;
use App\Support\ApiScope;
use App\Support\AttendanceSettings;
use App\Support\InstituteTheme;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * لقطة أولية لنطاق المستخدم — يستهلكها العميل عند أول تشغيل قبل أن تبدأ المزامنة
 * التزايدية عبر sync/pull. تُعيد المعهد والدورة الجارية وحلقاتِ صاحب الحساب.
 */
class BootstrapController extends Controller
{
    public function __invoke(Request $request, TeacherCircleQuery $teacherCircles): JsonResponse
    {
        $user = $request->user();
        $scope = ApiScope::for($user);
        $institute = $scope->institute();
        $course = $institute->currentCourse();

        return response()->json([
            'user' => [
                'name' => $user->name,
                // الدور هنا لا في /auth/login وحدها: هذه أول نقطة بعد الدخول ونطاقُها
                // محسوم، فيبني عليها التطبيق توجيهه بلا فحص 404 على /teacher/circles.
                'roles' => $user->getRoleNames(),
                // 🔄 م.6.1: الصلاحيات لا الأدوار وحدها — الديسكتوب يعرض أبواباً
                // يفترق فيها المشرفُ عن مدير المعهد داخل الدور الواحد (attendance.amend
                // مثلاً)، وبناءُ الواجهة على اسم الدور كان يعيد كتابة كتالوج الأدوار
                // في Dart فيفترق السطحان عند أول تعديل عليه.
                'permissions' => $scope->permissions(),
                // 🔄 م.5.3: معرّف صفّ الأستاذ نفسه — بدونه لا يستطيع العميل أن يرشّح
                // «حلقاتي» من مخزنه المحلي، لأن course_circle_teachers يصله في
                // sync/pull بمعرّف أستاذٍ لا يعرف أنه هو (SYNC-PROTOCOL §8 البند 7).
                'teacher_uuid' => $user->teacher?->uuid,
            ],
            'institute' => [
                'uuid' => $institute->uuid,
                'name' => $institute->name,
                'logo_path' => $institute->logo_path,
                // الألوان الثلاثة — منها يبني mousqe_ui سلالمَه بنفس نسب InstituteTheme.
                'theme' => InstituteTheme::for($institute)->toArray(),
                // ما يحتاجه العميل ليحسب دقائق التأخير محلياً قبل أن يؤكّدها الخادم.
                'attendance' => AttendanceSettings::for($institute)->toArray(),
            ],
            'course' => $course === null ? null : [
                'uuid' => $course->uuid,
                'name' => $course->name,
            ],
            'circles' => CourseCircleResource::collection($this->circles($user, $course, $teacherCircles)),
        ]);
    }

    /**
     * حلقاتُ صاحب الحساب: المسنَدةُ إليه إن كان أستاذاً، وحلقاتُ الدورة كلُّها لمن
     * يملك circles.view — وهي حالةُ المشرف ومديرِ المعهد في الديسكتوب.
     *
     * 🔄 م.6.1: كانت تعود `[]` لكل من ليس أستاذاً، فيفتح الديسكتوبُ على معهدٍ بلا
     * حلقات حتى تكتمل أولُ دورةِ sync/pull — وهي قد تكون آلافَ الصفوف على معهدٍ
     * قائمٍ منذ شهور. وشاشةُ أوّلِ تشغيل هي بالضبط ما بُنيت له هذه النقطة.
     *
     * @return Collection<int, CourseCircle>
     */
    private function circles(User $user, ?Course $course, TeacherCircleQuery $teacherCircles): Collection
    {
        if ($course === null) {
            return new Collection;
        }

        if ($user->teacher !== null) {
            return $teacherCircles->circles($user->teacher, $course);
        }

        if (! $user->can('circles.view')) {
            return new Collection;
        }

        return CourseCircle::query()
            ->where('course_id', $course->id)
            ->with(['circle', 'shift.days'])
            ->withCount('activeEnrollments')
            ->get();
    }
}
