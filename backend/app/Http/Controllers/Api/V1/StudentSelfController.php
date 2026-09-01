<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\AttendanceResource;
use App\Models\Student;
use App\Queries\StudentProfileQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * قراءة الطالب لبياناته الخاصة — تطبيق الطالب للقراءة فقط.
 */
class StudentSelfController extends Controller
{
    public function attendance(Request $request, StudentProfileQuery $query): JsonResponse
    {
        $student = $this->student($request);

        return response()->json([
            'summary' => $query->attendanceSummary($student),
            'trend' => $query->attendanceTrend($student),
            'recent' => AttendanceResource::collection($query->recentAttendances($student)),
        ]);
    }

    public function progress(Request $request, StudentProfileQuery $query): JsonResponse
    {
        $student = $this->student($request);

        return response()->json([
            'data' => $query->progressByCurriculum($student),
        ]);
    }

    private function student(Request $request): Student
    {
        $student = $request->user()->student;

        if ($student === null) {
            throw new NotFoundHttpException('هذا الحساب ليس حساب طالب.');
        }

        return $student;
    }
}
