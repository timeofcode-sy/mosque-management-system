<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\CourseCircleResource;
use App\Queries\TeacherCircleQuery;
use App\Support\ApiScope;
use App\Support\AttendanceSettings;
use App\Support\InstituteTheme;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * لقطة أولية لنطاق المستخدم — يستهلكها العميل عند أول تشغيل قبل أن تبدأ المزامنة
 * التزايدية عبر sync/pull. تُعيد المعهد والدورة الجارية، وحلقات الأستاذ إن وُجد.
 */
class BootstrapController extends Controller
{
    public function __invoke(Request $request, TeacherCircleQuery $teacherCircles): JsonResponse
    {
        $user = $request->user();
        $institute = ApiScope::for($user)->institute();
        $course = $institute->currentCourse();

        return response()->json([
            'user' => [
                'name' => $user->name,
                // الدور هنا لا في /auth/login وحدها: هذه أول نقطة بعد الدخول ونطاقُها
                // محسوم، فيبني عليها التطبيق توجيهه بلا فحص 404 على /teacher/circles.
                'roles' => $user->getRoleNames(),
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
            'circles' => $user->teacher === null || $course === null
                ? []
                : CourseCircleResource::collection($teacherCircles->circles($user->teacher, $course)),
        ]);
    }
}
