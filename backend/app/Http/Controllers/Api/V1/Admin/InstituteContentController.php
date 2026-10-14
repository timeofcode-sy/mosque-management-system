<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Actions\GenerateAccount;
use App\Actions\PublishAnnouncement;
use App\Actions\SaveCustomField;
use App\Actions\SavePersonalTrait;
use App\Actions\SaveTeacher;
use App\Enums\CustomFieldType;
use App\Enums\TraitPolarity;
use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\CustomField;
use App\Models\Institute;
use App\Models\PersonalTrait;
use App\Models\Teacher;
use App\Queries\AnnouncementQuery;
use App\Support\ApiScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use RuntimeException;

/**
 * ما كان في اللوحة وحدها فصار في برنامج الإدارة: الأساتذةُ والإعلاناتُ والواصفاتُ المخصّصة والصفات.
 *
 * كتابةٌ بـREST كالكتالوج ([CatalogController]): الأساتذةُ والواصفاتُ والصفاتُ جداولُ تُزامَن، فما
 * يُكتب هنا يعود إلى مخزن الجهاز في `sync/pull`، ولا `GET` لها. والإعلاناتُ وحدها لا تُزامَن إلى
 * الإدارة، فلها قراءتُها. والأفعالُ نفسُها التي تكتب بها اللوحة — لا قواعدُ ثانية.
 */
class InstituteContentController extends Controller
{
    // ---------------------------------------------------------------- الأساتذة

    public function storeTeacher(Request $request, SaveTeacher $save): JsonResponse
    {
        $teacher = $save->handle($this->institute($request), $request->validate(SaveTeacher::rules()));

        return response()->json(['data' => self::teacherPayload($teacher->refresh())], 201);
    }

    public function updateTeacher(Request $request, string $uuid, SaveTeacher $save): JsonResponse
    {
        $institute = $this->institute($request);
        $teacher = Teacher::query()->where('institute_id', $institute->id)->where('uuid', $uuid)->firstOrFail();

        $teacher = $save->handle($institute, $request->validate(SaveTeacher::rules()), $teacher);

        return response()->json(['data' => self::teacherPayload($teacher)]);
    }

    public function destroyTeacher(Request $request, string $uuid): JsonResponse
    {
        Teacher::query()->where('institute_id', $this->institute($request)->id)->where('uuid', $uuid)->firstOrFail()->delete();

        return response()->json(['deleted' => true]);
    }

    /**
     * حسابٌ لأستاذٍ بلا حساب — وكلمتُه تعود مرّةً واحدة.
     */
    public function teacherAccount(Request $request, string $uuid, GenerateAccount $generate): JsonResponse
    {
        $teacher = Teacher::query()->where('institute_id', $this->institute($request)->id)->where('uuid', $uuid)->firstOrFail();

        $result = $generate->handle($teacher);

        if ($result === null) {
            return response()->json(['message' => 'لهذا الأستاذ حسابٌ أصلاً.'], 422);
        }

        return response()->json([
            'credentials' => ['username' => $result['user']->username, 'password' => $result['password']],
        ], 201);
    }

    // ---------------------------------------------------------------- الإعلانات

    public function announcements(Request $request, AnnouncementQuery $query): JsonResponse
    {
        return response()->json([
            'data' => $query->forInstitute($this->institute($request))
                ->map(fn (Announcement $announcement): array => self::announcementPayload($announcement))
                ->values()
                ->all(),
        ]);
    }

    public function storeAnnouncement(Request $request, PublishAnnouncement $publish): JsonResponse
    {
        $announcement = $publish->handle($this->institute($request), $this->announcementAttributes($request), $request->user());

        return response()->json(['data' => self::announcementPayload($announcement)], 201);
    }

    public function updateAnnouncement(Request $request, string $uuid, PublishAnnouncement $publish): JsonResponse
    {
        $institute = $this->institute($request);
        $announcement = Announcement::query()->where('institute_id', $institute->id)->where('uuid', $uuid)->firstOrFail();

        $announcement = $publish->handle($institute, $this->announcementAttributes($request, $announcement), $request->user(), $announcement);

        return response()->json(['data' => self::announcementPayload($announcement)]);
    }

    /**
     * السحبُ إخفاءٌ لا حذف — كما في اللوحة: يُعاد نشرُه بالتعديل.
     */
    public function unpublishAnnouncement(Request $request, string $uuid): JsonResponse
    {
        $announcement = Announcement::query()->where('institute_id', $this->institute($request)->id)->where('uuid', $uuid)->firstOrFail();
        $announcement->update(['published_at' => null]);

        return response()->json(['data' => self::announcementPayload($announcement->refresh())]);
    }

    // ---------------------------------------------------------------- الواصفات والصفات

    public function storeField(Request $request, SaveCustomField $save): JsonResponse
    {
        $field = $save->handle($this->institute($request), $this->fieldAttributes($request));

        return response()->json(['data' => ['uuid' => $field->uuid]], 201);
    }

    public function updateField(Request $request, string $uuid, SaveCustomField $save): JsonResponse
    {
        $institute = $this->institute($request);
        $field = CustomField::query()->where('institute_id', $institute->id)->where('uuid', $uuid)->firstOrFail();

        $field = $save->handle($institute, $this->fieldAttributes($request), $field);

        return response()->json(['data' => ['uuid' => $field->uuid]]);
    }

    public function destroyField(Request $request, string $uuid): JsonResponse
    {
        CustomField::query()->where('institute_id', $this->institute($request)->id)->where('uuid', $uuid)->firstOrFail()->delete();

        return response()->json(['deleted' => true]);
    }

    public function storeTrait(Request $request, SavePersonalTrait $save): JsonResponse
    {
        $trait = $save->handle($this->institute($request), $this->traitAttributes($request));

        return response()->json(['data' => ['uuid' => $trait->uuid]], 201);
    }

    public function updateTrait(Request $request, string $uuid, SavePersonalTrait $save): JsonResponse
    {
        $institute = $this->institute($request);
        $trait = PersonalTrait::query()->where('institute_id', $institute->id)->where('uuid', $uuid)->firstOrFail();

        $trait = $save->handle($institute, $this->traitAttributes($request), $trait);

        return response()->json(['data' => ['uuid' => $trait->uuid]]);
    }

    public function destroyTrait(Request $request, string $uuid, SavePersonalTrait $save): JsonResponse
    {
        $trait = PersonalTrait::query()->where('institute_id', $this->institute($request)->id)->where('uuid', $uuid)->firstOrFail();

        try {
            $save->delete($trait);
        } catch (RuntimeException $exception) {
            return response()->json(['message' => $exception->getMessage()], 422);
        }

        return response()->json(['deleted' => true]);
    }

    // ---------------------------------------------------------------- مساعدات

    private function institute(Request $request): Institute
    {
        return ApiScope::for($request->user())->institute();
    }

    /**
     * @return array<string, mixed>
     */
    private function announcementAttributes(Request $request, ?Announcement $existing = null): array
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:5000'],
            'scope' => ['required', 'in:all,circle'],
            'scope_ids' => ['array', 'required_if:scope,circle'],
            'scope_ids.*' => ['integer'],
            'audience' => ['required', 'array', 'min:1'],
            'audience.*' => [Rule::in(Announcement::AUDIENCES)],
            'publish' => ['boolean'],
        ]);

        return [
            ...$validated,
            // التعديلُ لا يغيّر تاريخ النشر الأول؛ و`publish: false` يحفظه مسودّة.
            'published_at' => ($validated['publish'] ?? true) ? ($existing?->published_at ?? now()) : null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function fieldAttributes(Request $request): array
    {
        return $request->validate([
            'entity' => ['required', Rule::in(array_keys(SaveCustomField::ENTITIES))],
            'label' => ['required', 'string', 'max:255'],
            'key' => ['nullable', 'string', 'max:64', 'regex:/^[a-z0-9_]*$/'],
            'type' => ['required', Rule::enum(CustomFieldType::class)],
            'options' => ['nullable', 'array'],
            'options.*' => ['string', 'max:255'],
            'group' => ['nullable', 'string', 'max:64'],
            'is_required' => ['boolean'],
            'is_active' => ['boolean'],
            'sort_order' => ['integer', 'min:0'],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function traitAttributes(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'polarity' => ['required', Rule::enum(TraitPolarity::class)],
            'color' => ['nullable', 'string', 'max:16'],
            'sort_order' => ['integer', 'min:0'],
            'is_active' => ['boolean'],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private static function teacherPayload(Teacher $teacher): array
    {
        return [
            'uuid' => $teacher->uuid,
            'display_name' => $teacher->display_name,
            'status' => $teacher->status?->value,
            'has_account' => $teacher->user_id !== null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private static function announcementPayload(Announcement $announcement): array
    {
        return [
            'uuid' => $announcement->uuid,
            'title' => $announcement->title,
            'body' => $announcement->body,
            'scope' => $announcement->scope,
            'scope_ids' => array_map('intval', $announcement->scope_ids ?? []),
            'audience' => $announcement->audience ?? ['students'],
            'published_at' => $announcement->published_at?->toIso8601String(),
            'author' => $announcement->createdBy?->name,
        ];
    }
}
