<?php

namespace App\Http\Resources\V1;

use App\Queries\StudentStandingQuery;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * موقعُ الطالب بين زملائه — ✅ م.8.1، **رقمٌ لا كشف**.
 *
 * 🔑 وهذا المورد هو موضعُ القرار 1.1 في
 * [PHASE-8-STAGES.MD](../../../../docs/PHASE-8-STAGES.MD): كان الترتيبُ سيُحسب
 * على الجهاز، وذاك يعني أن يستقبل هاتفُ الطالب **صفوفَ حضورِ كلِّ زملائه**
 * ليستخرج منها رقماً واحداً. فقُلب الاتجاه: الخادمُ يحسب والجهازُ يعرض.
 *
 * **فلا اسمَ زميلٍ في الخرج ولا نسبتُه** — «الخامس من عشرين» وحدها.
 *
 * @mixin StudentStandingQuery
 */
class StandingResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var array{circle_name: ?string, rank: ?int, peers: int, rate: ?float, points: float} $standing */
        $standing = $this->resource;

        return [
            'circle_name' => $standing['circle_name'],
            // `null` تعني **لم يُقَس** لا «الأخير»: طالبٌ بلا تسجيلٍ جارٍ، أو حلقةٌ
            // لم يُتفقَّد فيها أحدٌ بعد. وهي قاعدةُ م.6.6 نفسُها.
            'rank' => $standing['rank'],
            'peers' => $standing['peers'],
            'rate' => $standing['rate'],
            'points' => $standing['points'],
        ];
    }
}
