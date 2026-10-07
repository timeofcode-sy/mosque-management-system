<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\SubmitAbsenceExcuse;
use App\Http\Controllers\Controller;
use App\Http\Resources\V1\AbsenceExcuseResource;
use App\Http\Resources\V1\AttendanceResource;
use App\Http\Resources\V1\ProgressResource;
use App\Http\Resources\V1\StudentResource;
use App\Models\Guardian;
use App\Models\Student;
use App\Queries\GuardianChildrenQuery;
use App\Queries\StudentProfileQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * ما يقرؤه وليُّ الأمر عن أبنائه، وكتابتُه الوحيدة: تقديمُ إذن غياب.
 *
 * 🔑 **وليُّ الأمر لا يستدعي `sync/pull` إطلاقاً** — القرارُ 0.1 في
 * [PHASE-7-STAGES.MD](../../../../../docs/PHASE-7-STAGES.MD). التيّارُ يبثّ
 * **معهداً كاملاً** لكل الأدوار ([SYNC-PROTOCOL.md §4](../../../../../docs/SYNC-PROTOCOL.md))،
 * وذاك على جهاز الأستاذ حِملٌ وعلى جهاز الأب **تسريب**: أسماءُ كلِّ طلاب المعهد
 * وحضورُهم في هاتف كلِّ وليّ. ولا يحتاجه أصلاً — من يستدعي التيّارَ من يكتب في
 * الطابور، وهو لا يملك `sync.push`.
 *
 * فهذه النقاطُ **كلُّ** مصادرِ التطبيق، ولذلك تعيد ما يُعرَض جاهزاً — الملخّصَ
 * والمنحنى محسوبين — لا صفوفاً يجمعها العميل.
 */
class GuardianController extends Controller
{
    public function children(Request $request, GuardianChildrenQuery $query): JsonResponse
    {
        return response()->json([
            'data' => StudentResource::collection($query->children($this->guardian($request))),
        ]);
    }

    /**
     * حضورُ ابنٍ بعينه: الملخّصُ والمنحنى والسجلُّ.
     *
     * 🔄 م.7.1 — كان يعيد `{"data": [ …سجلّات… ]}`. صار شكلُه **شكلَ**
     * `/student/me/attendance` ([API.md §3.7](../../../../../docs/API.md)) لأن
     * الشاشتين تعرضان الشيءَ نفسَه لجمهورين: الأبُ يرى نسبةَ ابنه والابنُ يرى
     * نسبتَه. وعقدان مختلفان لنفس الرقم يعنيان حسابَه مرّتين — وهو بالضبط ما
     * صار إليه `AttendanceRate` في م.6.6 حين تكرّر في Dart.
     *
     * ولا عميلَ يستهلك الشكلَ القديم: `apps/guardian/` لم يُبنَ بعد.
     */
    public function childAttendance(
        Request $request,
        string $student,
        GuardianChildrenQuery $children,
        StudentProfileQuery $profile,
    ): JsonResponse {
        $child = $children->child($this->guardian($request), $student);

        return response()->json([
            'summary' => $profile->attendanceSummary($child),
            'trend' => $profile->attendanceTrend($child),
            // ثلاثون لا عشرون: عقدُ ولي الأمر منذ [API.md §3.6] «آخر 30 سجلاً»،
            // وهو يقرأ شهراً كاملاً بينما الطالبُ يقرأ آخرَ أسبوعين تقريباً.
            'recent' => AttendanceResource::collection($profile->recentAttendances($child, 30)),
        ]);
    }

    /**
     * تقدُّمُ حفظِ ابنٍ بعينه، مجمَّعاً باسم المنهج — ✅ م.7.1، نقطةٌ جديدة.
     */
    public function childProgress(
        Request $request,
        string $student,
        GuardianChildrenQuery $children,
        StudentProfileQuery $profile,
    ): JsonResponse {
        $child = $children->child($this->guardian($request), $student);

        return response()->json([
            'data' => $this->groupedProgress($profile, $child),
        ]);
    }

    /**
     * 🔴 م.7.4: **الخريطةُ الفارغة تُجبَر كائناً `{}` لا مصفوفةً `[]`**.
     *
     * `groupBy` على مجموعةٍ فارغة يعطي مجموعةً فارغة، و`json_encode` يخرجها
     * `[]` — أي **يبدّل نوعَ الحقل بحسب محتواه**: كائنٌ حين يكون فيه منهجٌ
     * واحد، ومصفوفةٌ حين لا يكون. فيرمي العميلُ عند فكّ الحمولة، والطالبُ
     * الجديد بلا محفوظاتٍ هو **الحالةُ الأغلب** لا النادرة.
     *
     * كُشف بتجريبٍ على جهاز: النقطةُ ردّت 200 والشاشةُ عرضت «حدث خطأ غير
     * متوقّع». ولم تكشفه الاختبارات لأنها تنشئ صفَّ تقدُّمٍ قبل القراءة —
     * **فالحالةُ الفارغة لم تُختبَر أصلاً**.
     */
    private function groupedProgress(StudentProfileQuery $profile, Student $child): object
    {
        return (object) $profile->progressByCurriculum($child)
            ->map(fn ($entries) => ProgressResource::collection($entries))
            ->all();
    }

    /**
     * أعذارُ أبنائه وحالتُها — ✅ م.7.1، نقطةٌ جديدة.
     */
    public function excuses(Request $request, GuardianChildrenQuery $query): JsonResponse
    {
        return response()->json([
            'data' => AbsenceExcuseResource::collection($query->excuses($this->guardian($request))),
        ]);
    }

    public function submitExcuse(Request $request, SubmitAbsenceExcuse $action, GuardianChildrenQuery $children): JsonResponse
    {
        $guardian = $this->guardian($request);

        $validated = $request->validate([
            'student_uuid' => ['required', 'uuid'],
            'from_date' => ['required', 'date'],
            'to_date' => ['required', 'date', 'after_or_equal:from_date'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $student = $children->child($guardian, $validated['student_uuid']);

        $excuse = $action->handle($student, $validated, $request->user());

        return response()->json(['uuid' => $excuse->uuid, 'status' => $excuse->status], 201);
    }

    private function guardian(Request $request): Guardian
    {
        $guardian = $request->user()->guardian;

        if ($guardian === null) {
            throw new NotFoundHttpException('هذا الحساب ليس حساب ولي أمر.');
        }

        return $guardian;
    }
}
