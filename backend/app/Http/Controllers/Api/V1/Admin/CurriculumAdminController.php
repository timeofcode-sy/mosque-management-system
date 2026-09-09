<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Actions\SaveCurriculum;
use App\Actions\SaveCurriculumItem;
use App\Enums\CurriculumType;
use App\Http\Controllers\Controller;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\Institute;
use App\Support\ApiScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use RuntimeException;

/**
 * المناهجُ وبنودُها — ✅ م.6.5، وهي **الفجوةُ المسمّاة** منذ م.6.2
 * ([CHECKPOINT-PHASE-6.2.MD §10] البند 4): `SaveCurriculumItem` قائمٌ منذ م.4.5
 * ولا غلافَ له، فكان بابُ المناهج في الديسكتوب يحتاج متصفّحاً.
 *
 * **ولماذا REST لا طابور؟** نفسُ حجج بنية الدورة في [CatalogController]: المنهجُ
 * بنيةٌ يُبنى عليها لا حدثٌ يُسجَّل — سجلُّ محفوظات الطالب يُعلَّق على بنوده،
 * فبندٌ يُصفّ أوف-لاين ثم يُرفض يُسقط ما بُني فوقه. ويُهيَّأ مرّةً في الفصل من
 * مكتب.
 *
 * ولا `GET` هنا: `curricula` و`curriculum_items` جدولان يُزامَنان، فما يُكتب هنا
 * يصل مخزنَ الجهاز في دورته التالية ([APPS-FEATURES.md §4.3]).
 */
class CurriculumAdminController extends Controller
{
    private const FIXED_QURAN = 'أجزاء القرآن ثابتة ولا تُضاف ولا تُحذف.';

    public function store(Request $request, SaveCurriculum $saveCurriculum): JsonResponse
    {
        $institute = $this->institute($request);

        $curriculum = $saveCurriculum->handle($institute, $this->attributes($request));

        return response()->json(['data' => self::payload($curriculum)], 201);
    }

    public function update(Request $request, string $uuid, SaveCurriculum $saveCurriculum): JsonResponse
    {
        $institute = $this->institute($request);
        $curriculum = $this->curriculum($uuid, $institute);

        try {
            $curriculum = $saveCurriculum->handle($institute, $this->attributes($request), $curriculum);
        } catch (RuntimeException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        return response()->json(['data' => self::payload($curriculum)]);
    }

    public function storeItem(Request $request, string $uuid, SaveCurriculumItem $saveItem): JsonResponse
    {
        $curriculum = $this->curriculum($uuid, $this->institute($request));

        if ($curriculum->type === CurriculumType::Quran) {
            return response()->json(['message' => self::FIXED_QURAN], 422);
        }

        $item = $saveItem->handle($curriculum, $this->itemAttributes($request, $curriculum));

        return response()->json(['data' => self::itemPayload($item)], 201);
    }

    public function updateItem(Request $request, string $uuid, SaveCurriculumItem $saveItem): JsonResponse
    {
        $institute = $this->institute($request);
        $item = $this->item($uuid, $institute);
        $curriculum = $item->curriculum;

        // تحريرُ اسم جزءٍ قائم مسموح، وإضافةُ جزءٍ وحذفُه ممنوعان — نفسُ تفريق
        // شاشة اللوحة حرفياً: الثابتُ عددُها لا أسماؤها.
        $item = $saveItem->handle($curriculum, $this->itemAttributes($request, $curriculum, $item), $item->id);

        return response()->json(['data' => self::itemPayload($item)]);
    }

    public function destroyItem(Request $request, string $uuid): JsonResponse
    {
        $item = $this->item($uuid, $this->institute($request));

        if ($item->curriculum->type === CurriculumType::Quran) {
            return response()->json(['message' => self::FIXED_QURAN], 422);
        }

        // بندٌ عُلّق عليه سجلُّ محفوظات لا يُحذف: حذفُه يترك تقدّمَ الطالب معلّقاً
        // بلا بندٍ يفسّره — والقاعدةُ نفسُها في شاشة اللوحة.
        if ($item->progress()->exists()) {
            return response()->json(['message' => 'لا يمكن حذف بند مرتبط بسجل محفوظات.'], 422);
        }

        $item->delete();

        return response()->json(['data' => ['uuid' => $uuid, 'deleted' => true]]);
    }

    /**
     * @return array<string, mixed>
     */
    private function attributes(Request $request): array
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'type' => ['required', Rule::enum(CurriculumType::class)],
            'description' => ['nullable', 'string'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'is_active' => ['nullable', 'boolean'],
        ], attributes: ['name' => 'اسم المنهج']);

        return array_filter($validated, fn ($value): bool => $value !== null);
    }

    /**
     * الرمزُ فريدٌ داخل المنهج، و`SaveCurriculumItem` يشتقّه حين يُترك فارغاً —
     * فالتحقّقُ هنا على المذكور وحده.
     *
     * @return array<string, mixed>
     */
    private function itemAttributes(Request $request, Curriculum $curriculum, ?CurriculumItem $item = null): array
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => [
                'nullable', 'string', 'max:64',
                Rule::unique('curriculum_items', 'code')
                    ->where('curriculum_id', $curriculum->id)
                    ->ignore($item?->id),
            ],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'count' => ['nullable', 'integer', 'min:0', 'max:10000'],
        ], attributes: ['name' => 'اسم البند', 'code' => 'الرمز', 'count' => 'العدّاد']);

        return array_filter([
            'name' => $validated['name'],
            'code' => $validated['code'] ?? null,
            'sort_order' => $validated['sort_order'] ?? null,
            'meta' => self::metaFor($curriculum, $validated['count'] ?? null),
        ], fn ($value): bool => $value !== null && $value !== []);
    }

    /**
     * مفتاحُ العدّاد يتبع نوعَ المنهج — الأحاديثُ للحديث والأبياتُ للمتون، ولا
     * عدّادَ لسواهما (م.4.5). والقيمةُ تُدمج في `meta` ولا تمسح ما زرعته البذرة.
     *
     * @return array<string, mixed>
     */
    private static function metaFor(Curriculum $curriculum, ?int $count): array
    {
        $key = match ($curriculum->type) {
            CurriculumType::Hadith => 'hadiths',
            CurriculumType::Mutun => 'abyat',
            default => null,
        };

        return $key === null || $count === null ? [] : [$key => $count];
    }

    private function institute(Request $request): Institute
    {
        return ApiScope::for($request->user())->institute();
    }

    /**
     * منهجُ هذا المعهد **أو المنهجُ العامّ** — الشاشةُ تعرض الاثنين
     * (`InstituteCatalogQuery::curricula`)، والفرقُ في الحكم لا في الرؤية:
     * العامُّ تُضاف إليه بنودٌ ولا يُحرَّر وعاؤه ([SaveCurriculum::assertOwned]).
     */
    private function curriculum(string $uuid, Institute $institute): Curriculum
    {
        return Curriculum::query()
            ->where('uuid', $uuid)
            ->where(fn ($query) => $query->whereNull('institute_id')->orWhere('institute_id', $institute->id))
            ->firstOrFail();
    }

    private function item(string $uuid, Institute $institute): CurriculumItem
    {
        return CurriculumItem::query()
            ->where('uuid', $uuid)
            ->whereHas('curriculum', fn ($query) => $query
                ->where(fn ($inner) => $inner->whereNull('institute_id')->orWhere('institute_id', $institute->id)))
            ->with('curriculum')
            ->firstOrFail();
    }

    /**
     * @return array<string, mixed>
     */
    private static function payload(Curriculum $curriculum): array
    {
        return [
            'uuid' => $curriculum->uuid,
            'name' => $curriculum->name,
            'slug' => $curriculum->slug,
            'type' => $curriculum->type->value,
            'description' => $curriculum->description,
            'sort_order' => $curriculum->sort_order,
            'is_active' => (bool) $curriculum->is_active,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private static function itemPayload(CurriculumItem $item): array
    {
        return [
            'uuid' => $item->uuid,
            'curriculum_uuid' => $item->curriculum?->uuid,
            'name' => $item->name,
            'code' => $item->code,
            'sort_order' => $item->sort_order,
            'meta' => $item->meta,
            'is_active' => (bool) $item->is_active,
        ];
    }
}
