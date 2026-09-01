<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\CourseCircleResource;
use App\Queries\TeacherCircleQuery;
use App\Support\ApiScope;
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
            'institute' => [
                'uuid' => $institute->uuid,
                'name' => $institute->name,
                'logo_path' => $institute->logo_path,
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
