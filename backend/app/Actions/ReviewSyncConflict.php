<?php

namespace App\Actions;

use App\Models\SyncConflict;
use App\Models\User;
use Illuminate\Support\Carbon;

/**
 * إبقاءُ حكم الخادم: يُختم التعارض مراجَعاً ولا يُكتب شيء — الصفّ يحمل قيمة الخادم
 * منذ لحظة الدفع، فالقرارُ هنا «لا تفعل» موثَّقاً باسم من قرّره ووقتِه.
 *
 * نظيرُ OverturnSyncConflict في الاتجاه الآخر، وأُخرج من مكوّن اللوحة إلى فعلٍ مشترك
 * لأن الديسكتوب (م.6) صار يحكم في التعارضات كما تحكم اللوحة — والقاعدة في
 * [ARCHITECTURE.md §3] أن منطق الكتابة لا يُكتب مرّتين لسطحين.
 */
class ReviewSyncConflict
{
    public function handle(SyncConflict $conflict, User $reviewedBy): void
    {
        $conflict->update([
            'reviewed_by' => $reviewedBy->id,
            'resolved_at' => Carbon::now(),
        ]);
    }
}
