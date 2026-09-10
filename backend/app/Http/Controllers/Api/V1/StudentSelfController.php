<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\AttendanceResource;
use App\Http\Resources\V1\ProgressResource;
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

    /**
     * 🔄 م.7.1: صارت تمرّ بـ`ProgressResource` كنظيرتِها عند ولي الأمر.
     *
     * كانت **النقطةَ الوحيدة في النظام** التي تعيد نموذجاً خاماً: كلَّ أعمدة
     * `student_curriculum_progress` بمفاتيحها الداخلية وبشكلٍ غير مثبَّتٍ بعقد،
     * وكان تثبيتُها مؤجَّلاً إلى «ما قبل م.8» ([API.md §8](../../../../../docs/API.md)).
     * قُدّم لأن م.7.1 فتحت نقطةَ تقدُّمٍ ثانيةً لولي الأمر، ولا معنى لأن يُثبَّت
     * شكلُ إحداهما ويُترك شكلُ الأخرى — ولا لأن يُضاعَف غيرُ المثبَّت.
     */
    public function progress(Request $request, StudentProfileQuery $query): JsonResponse
    {
        $student = $this->student($request);

        return response()->json([
            'data' => $query->progressByCurriculum($student)
                ->map(fn ($entries) => ProgressResource::collection($entries)),
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
