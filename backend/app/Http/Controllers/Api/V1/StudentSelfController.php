<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\V1\AnnouncementResource;
use App\Http\Resources\V1\AttendanceResource;
use App\Http\Resources\V1\ProgressResource;
use App\Http\Resources\V1\StandingResource;
use App\Models\Student;
use App\Queries\AnnouncementQuery;
use App\Queries\StudentPointsQuery;
use App\Queries\StudentProfileQuery;
use App\Queries\StudentStandingQuery;
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

        // 🔴 م.7.4: `(object)` تُجبر الخريطةَ الفارغة على `{}` بدل `[]` — وإلا
        // بدّل الحقلُ **نوعَه** بحسب محتواه فرمى العميلُ عند فكّ الحمولة. كُشف في
        // نقطة ولي الأمر بتجريبٍ على جهاز، وهذه نظيرتُها حرفياً
        // ([GuardianController::groupedProgress](GuardianController.php)).
        return response()->json([
            'data' => (object) $query->progressByCurriculum($student)
                ->map(fn ($entries) => ProgressResource::collection($entries))
                ->all(),
        ]);
    }

    /**
     * موقعُه بين زملائه — ✅ م.8.1، **رقمٌ لا كشف**.
     *
     * 🔑 الرتبةُ تُحسب في الخادم لأن حسابَها على الجهاز يعني أن يستقبل هاتفُ
     * الطالب صفوفَ حضورِ كلِّ زملائه ليستخرج منها رقماً واحداً
     * ([PHASE-8-STAGES.MD §1.1](../../../../../docs/PHASE-8-STAGES.MD)).
     */
    public function standing(Request $request, StudentStandingQuery $query): JsonResponse
    {
        return response()->json([
            'data' => new StandingResource($query->for($this->student($request))),
        ]);
    }

    /**
     * نقاطُه بمصادرها الخمسة في الدورة الجارية — ✅ م.8.1.
     *
     * `student_points` جدولٌ يُزامَن، لكنّ الطالبَ خارج التيّار (§1.1) —
     * و`StudentPointsQuery` قائمٌ منذ م.4.5، فالغلافُ وحده كان ينقص.
     */
    public function points(Request $request, StudentPointsQuery $query): JsonResponse
    {
        $student = $this->student($request);
        $course = $student->institute?->currentCourse();

        if ($course === null) {
            // لا دورةَ جارية ⇒ أصفارٌ لا خطأ: معهدٌ بين دورتين حالٌ عادية،
            // وشاشةُ الطالب تعرض صفراً مفهوماً لا رسالةَ عطب.
            return response()->json(['data' => StudentPointsQuery::EMPTY]);
        }

        return response()->json([
            'data' => $query->forStudent(
                $student,
                $course->starts_on->toDateString(),
                $course->ends_on->toDateString(),
            ),
        ]);
    }

    /**
     * إعلاناتُ معهده وحلقته — ✅ م.8.1، والترشيحُ في الخادم (§1.3).
     */
    public function announcements(Request $request, AnnouncementQuery $query): JsonResponse
    {
        return response()->json([
            'data' => AnnouncementResource::collection($query->forStudent($this->student($request))),
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
