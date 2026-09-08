<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Actions\CreateInstitute;
use App\Http\Controllers\Controller;
use App\Models\Institute;
use App\Support\ApiScope;
use App\Support\AttendanceSettings;
use App\Support\InstituteForm;
use App\Support\InstituteTheme;
use App\Support\PointsSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * بياناتُ المعهد وألوانُه وإعداداتُه — سطحُ الإدارة في الـ API، ✅ م.6.2.
 *
 * **لماذا REST لا نوعُ عمليةٍ في الطابور؟** بحسب قاعدة [PHASE-6-STAGES.MD §3.1]:
 * ما يُكتب أوف-لاين ويقبل التأخير يمرّ بالطابور، وما هو متّصلٌ بطبعه يمرّ هنا.
 * وتغييرُ ألوان المعهد يريد صاحبُه أن يراها فوراً في كل جهاز، وإنشاءُ معهدٍ حدثٌ
 * نادر متّصل — ولا معنى لطابورٍ يحمل معهداً إلى وقتٍ لاحق.
 *
 * ولا نقطةَ قراءةٍ هنا: `institutes` جدولٌ **يُزامَن**، فالديسكتوب يقرأ معهدَه من
 * مخزنه لا من الشبكة، وقائمةُ معاهده في `GET /institutes` منذ م.6.1
 * ([API.md §3.8]). ما ينقصه هو الكتابةُ وحدها.
 *
 * والقواعدُ مقروءةٌ من InstituteForm نفسِه الذي تستعمله شاشتا اللوحة: نموذجٌ واحد
 * للمعهد لا نموذجان يفترقان عند أوّل تعديل.
 */
class InstituteAdminController extends Controller
{
    /**
     * تحرير **المعهد العامل** — خلف `settings.manage`.
     */
    public function updateCurrent(Request $request): JsonResponse
    {
        $institute = ApiScope::for($request->user())->institute();

        $institute->fill($this->attributesFrom($request, $institute))->save();

        return response()->json(['data' => self::payload($institute->refresh())]);
    }

    /**
     * إنشاء معهد — خلف `institutes.manage`، ومعه دورةٌ أولى مسودّة (CreateInstitute).
     */
    public function store(Request $request, CreateInstitute $createInstitute): JsonResponse
    {
        $institute = $createInstitute->handle($this->attributesFrom($request, null));

        return response()->json(['data' => self::payload($institute)], 201);
    }

    /**
     * تحرير معهدٍ بعينه — خلف `institutes.manage`، فحاملُ الدور العابر وحده يبلغه
     * (`institutes.manage` منزوعةٌ من `admin` عمداً — [APPS-FEATURES.md §4.3]).
     */
    public function update(Request $request, string $uuid): JsonResponse
    {
        $institute = Institute::query()->where('uuid', $uuid)->firstOrFail();

        $institute->fill($this->attributesFrom($request, $institute))->save();

        return response()->json(['data' => self::payload($institute->refresh())]);
    }

    /**
     * الحقول جاهزةً للإسناد، مُتحقَّقاً منها بقواعد اللوحة نفسِها.
     *
     * **المجموعاتُ الثلاث (الألوان · التفقّد · النقاط) تُملأ من الحالة القائمة حين
     * لا تصل**: قواعدُ InstituteForm تطلبها كاملةً لأن اللوحة ترسل النموذج كلَّه في
     * كل حفظ، والديسكتوبُ قد يبعث بابَ الألوان وحده. فبدل تليين القاعدة — وهو ما
     * يجعل نموذجين — تُكمَّل الحمولةُ بما هو مخزَّن أصلاً.
     *
     * ⚠️ الشعار (`logo_path`) خارج هذه النقطة: رفعُ ملفٍّ عقدٌ آخر (multipart) لم
     * يُفتح بعد — [API.md §8].
     *
     * @return array<string, mixed>
     */
    private function attributesFrom(Request $request, ?Institute $institute): array
    {
        $rules = InstituteForm::rules();
        unset($rules['logo']);

        $payload = [
            ...$request->only(['name', 'short_name', 'phone', 'email', 'address', 'is_active']),
            'theme' => $request->input('theme', InstituteTheme::for($institute)->toArray()),
            'attendance' => [
                'late_grace_minutes' => $request->input(
                    'attendance.late_grace_minutes',
                    AttendanceSettings::for($institute)->lateGraceMinutes(),
                ),
            ],
            'points' => $request->input('points', PointsSettings::for($institute)->toArray()),
        ];

        $validated = Validator::make($payload, $rules, attributes: InstituteForm::attributes())->validate();

        return InstituteForm::attributesFor($institute, $validated, $validated['points']);
    }

    /**
     * نفسُ شكل `institute` في `/bootstrap` ([API.md §3.4]) — فلا يتعلّم العميلُ
     * شكلين للمعهد الواحد.
     *
     * @return array<string, mixed>
     */
    public static function payload(Institute $institute): array
    {
        return [
            'uuid' => $institute->uuid,
            'name' => $institute->name,
            'short_name' => $institute->short_name,
            'phone' => $institute->phone,
            'email' => $institute->email,
            'address' => $institute->address,
            'is_active' => (bool) $institute->is_active,
            'logo_path' => $institute->logo_path,
            'theme' => InstituteTheme::for($institute)->toArray(),
            'attendance' => AttendanceSettings::for($institute)->toArray(),
            'points' => PointsSettings::for($institute)->toArray(),
        ];
    }
}
