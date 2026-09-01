<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\AttendanceSessionResource;
use App\Http\Resources\V1\CourseCircleResource;
use App\Models\CourseCircle;
use App\Models\Teacher;
use App\Queries\TeacherCircleQuery;
use App\Support\ApiScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * حلقات الأستاذ وجلساته — نطاقه محصور بما أُسند إليه فعلياً، لا كل حلقات المعهد.
 */
class TeacherController extends Controller
{
    public function circles(Request $request, TeacherCircleQuery $query): JsonResponse
    {
        $teacher = $this->teacher($request);
        $course = ApiScope::for($request->user())->institute()->currentCourse();

        return response()->json([
            'data' => CourseCircleResource::collection($query->circles($teacher, $course)),
        ]);
    }

    public function session(Request $request, string $date, TeacherCircleQuery $query): JsonResponse
    {
        $teacher = $this->teacher($request);
        $courseCircleUuid = $request->string('course_circle_uuid')->toString();

        $courseCircle = CourseCircle::query()
            ->where('uuid', $courseCircleUuid)
            ->whereHas('teachers', fn ($q) => $q->where('teachers.id', $teacher->id))
            ->firstOrFail();

        $session = $query->sessionOn($courseCircle, Carbon::parse($date)->toDateString());

        return response()->json([
            'data' => $session === null ? null : new AttendanceSessionResource($session),
        ]);
    }

    private function teacher(Request $request): Teacher
    {
        $teacher = $request->user()->teacher;

        if ($teacher === null) {
            throw new NotFoundHttpException('هذا الحساب ليس حساب أستاذ.');
        }

        return $teacher;
    }
}
