<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Actions\ActivateCourse;
use App\Actions\RunCircleInCourse;
use App\Actions\SaveCircle;
use App\Actions\SaveCourse;
use App\Actions\SaveShift;
use App\Enums\CourseStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\V1\CourseCircleResource;
use App\Models\Circle;
use App\Models\Course;
use App\Models\Institute;
use App\Models\Shift;
use App\Support\ApiScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use RuntimeException;

/**
 * الدوراتُ والدواماتُ والحلقات — الكتابةُ وحدَها، ✅ م.6.2.
 *
 * **القرار المطلوب في [PHASE-6-STAGES.MD §3.2] البند 3 مَحسوم هنا: REST لا طابور.**
 * ثلاثةُ أسباب، كلُّها من قاعدة §3.1:
 *
 * 1. **الكتابةُ نادرةٌ ومتّصلةٌ بطبعها** — تُهيَّأ الدورةُ ودواماتُها مرّةً في الفصل
 *    من مكتبٍ لا من مسجدٍ بلا شبكة، بخلاف التفقّد الذي يُكتب كل يوم أوف-لاين.
 * 2. **هي بنيةٌ يُبنى عليها لا حدثٌ يُسجَّل.** الجلسةُ والتسجيلُ والتفقّد تُعلَّق كلُّها
 *    على `course_circles`؛ ولو صُفَّت أوف-لاين لَصفَّ الجهازُ فوقها عشراتِ العمليات
 *    ثم رُفض أصلُها فسقط ما فوقه — وهو بالضبط ما تعالجه عزلةُ العملية المرفوضة، لا
 *    ما ينبغي أن يُستدعى عمداً.
 * 3. **الأثرُ يعود في `sync/pull` على أي حال** — الجداول الثلاثة تُزامَن، فما يُكتب
 *    هنا يصل مخزنَ الجهاز في دورته التالية بلا نقطةِ قراءةٍ ثانية.
 *
 * ولذلك لا `GET` في هذا المتحكّم: الديسكتوب يقرأ الكتالوج من drift لا من الشبكة
 * ([APPS-FEATURES.md §4.3] — «لا يصير مصدرَ الحقيقة»).
 */
class CatalogController extends Controller
{
    public function storeCourse(Request $request, SaveCourse $saveCourse): JsonResponse
    {
        $institute = $this->institute($request);

        $course = $saveCourse->handle($institute, $this->courseAttributes($request));

        return response()->json(['data' => self::coursePayload($course)], 201);
    }

    public function updateCourse(Request $request, string $uuid, SaveCourse $saveCourse): JsonResponse
    {
        $institute = $this->institute($request);
        $course = $this->course($uuid, $institute);

        $course = $saveCourse->handle($institute, $this->courseAttributes($request), $course);

        return response()->json(['data' => self::coursePayload($course)]);
    }

    /**
     * «اجعلها الدورة الجارية» — فعلٌ مستقلّ لأنه يمسّ كلَّ شاشةٍ تشغيلية في المعهد،
     * ولأنه يُنزل الجاريةَ السابقة (ActivateCourse).
     */
    public function activateCourse(Request $request, string $uuid, ActivateCourse $activateCourse): JsonResponse
    {
        $course = $this->course($uuid, $this->institute($request));

        $activateCourse->handle($course);

        return response()->json(['data' => self::coursePayload($course->refresh())]);
    }

    public function storeShift(Request $request, SaveShift $saveShift): JsonResponse
    {
        [$attributes, $weekdays, $course] = $this->shiftInput($request);

        return response()->json(['data' => self::shiftPayload($saveShift->handle($course, $attributes, $weekdays))], 201);
    }

    public function updateShift(Request $request, string $uuid, SaveShift $saveShift): JsonResponse
    {
        $institute = $this->institute($request);

        $shift = Shift::query()
            ->where('uuid', $uuid)
            ->whereHas('course', fn ($query) => $query->where('institute_id', $institute->id))
            ->firstOrFail();

        [$attributes, $weekdays, $course] = $this->shiftInput($request, $shift->course);

        return response()->json(['data' => self::shiftPayload($saveShift->handle($course, $attributes, $weekdays, $shift))]);
    }

    public function storeCircle(Request $request, SaveCircle $saveCircle): JsonResponse
    {
        $institute = $this->institute($request);

        $circle = $saveCircle->handle($institute, $this->circleAttributes($request));

        return response()->json(['data' => self::circlePayload($circle)], 201);
    }

    public function updateCircle(Request $request, string $uuid, SaveCircle $saveCircle): JsonResponse
    {
        $institute = $this->institute($request);

        $circle = Circle::query()->where('uuid', $uuid)->where('institute_id', $institute->id)->firstOrFail();

        $circle = $saveCircle->handle($institute, $this->circleAttributes($request), $circle);

        return response()->json(['data' => self::circlePayload($circle)]);
    }

    /**
     * تشغيلُ الحلقة في دورةٍ ودوام — الصفُّ الذي تُعلَّق عليه الجلساتُ والتسجيلات.
     */
    public function runCircle(Request $request, string $uuid, RunCircleInCourse $runCircle): JsonResponse
    {
        $institute = $this->institute($request);

        $validated = $request->validate([
            'course_uuid' => ['nullable', 'uuid'],
            'shift_uuid' => ['required', 'uuid'],
            'room' => ['nullable', 'string', 'max:255'],
            'capacity' => ['nullable', 'integer', 'min:1', 'max:500'],
        ]);

        $circle = Circle::query()->where('uuid', $uuid)->where('institute_id', $institute->id)->firstOrFail();
        $course = $this->courseOrCurrent($validated['course_uuid'] ?? null, $institute);

        $shift = Shift::query()
            ->where('uuid', $validated['shift_uuid'])
            ->where('course_id', $course->id)
            ->firstOrFail();

        try {
            $courseCircle = $runCircle->handle(
                $course,
                $circle,
                $shift,
                $validated['room'] ?? null,
                isset($validated['capacity']) ? (int) $validated['capacity'] : null,
            );
        } catch (RuntimeException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        $courseCircle->loadMissing('circle', 'shift')->loadCount('activeEnrollments');

        return response()->json(['data' => new CourseCircleResource($courseCircle)], 201);
    }

    /**
     * @return array<string, mixed>
     */
    private function courseAttributes(Request $request): array
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'starts_on' => ['required', 'date'],
            'ends_on' => ['nullable', 'date', 'after_or_equal:starts_on'],
            'status' => ['required', Rule::enum(CourseStatus::class)],
            'notes' => ['nullable', 'string'],
        ]);

        $validated['ends_on'] = $validated['ends_on'] ?? null;

        return $validated;
    }

    /**
     * @return array{0: array<string, mixed>, 1: array<int, int>, 2: Course}
     */
    private function shiftInput(Request $request, ?Course $course = null): array
    {
        $validated = $request->validate([
            'course_uuid' => ['nullable', 'uuid'],
            'name' => ['required', 'string', 'max:255'],
            'starts_at' => ['required', 'date_format:H:i'],
            'ends_at' => ['required', 'date_format:H:i', 'after:starts_at'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
            'weekdays' => ['required', 'array', 'min:1'],
            'weekdays.*' => ['integer', 'between:0,6'],
        ], attributes: ['weekdays' => 'أيام الدوام']);

        $weekdays = array_map('intval', $validated['weekdays']);

        unset($validated['weekdays'], $validated['course_uuid']);

        return [
            array_filter($validated, fn ($value): bool => $value !== null),
            $weekdays,
            $course ?? $this->courseOrCurrent($request->input('course_uuid'), $this->institute($request)),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function circleAttributes(Request $request): array
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'level' => ['nullable', 'string', 'max:255'],
            'color' => ['nullable', 'string', 'max:16'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
            'notes' => ['nullable', 'string'],
        ]);

        return array_filter($validated, fn ($value): bool => $value !== null);
    }

    private function institute(Request $request): Institute
    {
        return ApiScope::for($request->user())->institute();
    }

    private function course(string $uuid, Institute $institute): Course
    {
        return Course::query()->where('uuid', $uuid)->where('institute_id', $institute->id)->firstOrFail();
    }

    /**
     * الدورةُ المقصودة، أو الجاريةُ حين لا يُذكر معرّف — فأغلبُ الكتابة تقع على
     * الجارية، والذكرُ الصريح يبقى متاحاً لتهيئة دورةٍ قادمة.
     */
    private function courseOrCurrent(?string $uuid, Institute $institute): Course
    {
        if (filled($uuid)) {
            return $this->course($uuid, $institute);
        }

        $course = Course::query()->where('institute_id', $institute->id)->where('is_current', true)->first();

        if ($course === null) {
            // 422 لا 500: «لا دورة جارية» حالةُ معهدٍ لم يُهيَّأ بعد، يعرضها العميل
            // لصاحبه ليُنشئ دورةً — لا عطلٌ في الخادم.
            throw ValidationException::withMessages(['course_uuid' => 'لا توجد دورة جارية في هذا المعهد.']);
        }

        return $course;
    }

    /**
     * @return array<string, mixed>
     */
    private static function coursePayload(Course $course): array
    {
        return [
            'uuid' => $course->uuid,
            'name' => $course->name,
            'starts_on' => $course->starts_on?->toDateString(),
            'ends_on' => $course->ends_on?->toDateString(),
            'status' => $course->status->value,
            'is_current' => (bool) $course->is_current,
            'notes' => $course->notes,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private static function shiftPayload(Shift $shift): array
    {
        return [
            'uuid' => $shift->uuid,
            'course_uuid' => $shift->course?->uuid,
            'name' => $shift->name,
            'starts_at' => substr((string) $shift->starts_at, 0, 5),
            'ends_at' => substr((string) $shift->ends_at, 0, 5),
            'sort_order' => $shift->sort_order,
            'is_active' => (bool) $shift->is_active,
            'weekdays' => $shift->days()->pluck('weekday')->map(fn ($day): int => (int) $day)->all(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private static function circlePayload(Circle $circle): array
    {
        return [
            'uuid' => $circle->uuid,
            'name' => $circle->name,
            'level' => $circle->level,
            'color' => $circle->color,
            'sort_order' => $circle->sort_order,
            'is_active' => (bool) $circle->is_active,
            'notes' => $circle->notes,
        ];
    }
}
