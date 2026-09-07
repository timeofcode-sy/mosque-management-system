<?php

namespace App\Actions;

use App\Models\Attendance;
use App\Models\SyncConflict;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * قلبُ حكمٍ آليّ: اعتماد القيمة التي رفضها الخادم وقتَ الدفع.
 *
 * الحسم الآليّ في ResolveAttendanceConflicts يبقى كما هو — «الأحدث يفوز» يقع أثناء
 * دفعةٍ لا أمام بشر، ولا بديل عنه. وهذا الفعل **استئنافٌ بعديّ**: المشرف يرى القيمتين
 * فيقرّر أن قيمة الجهاز هي الصواب، فتُعاد كتابتها.
 *
 * وتمرّ بـ TakeAttendance لا بكتابةٍ مباشرة، فتُحسب دقائقُ التأخير ويُسجَّل التغيير في
 * change_log ويصل الأجهزةَ في سحبها التالي — وهي القاعدة نفسها في ARCHITECTURE §3.
 * ولذلك يُرفض القلبُ على جلسةٍ مقفلة: TakeAttendance ترفضها ولو بـ amend.
 */
class OverturnSyncConflict
{
    public function __construct(private TakeAttendance $takeAttendance) {}

    public function handle(SyncConflict $conflict, User $reviewedBy): void
    {
        if ($conflict->table_name !== 'attendances') {
            throw new RuntimeException('لا يُقلب إلا تعارضُ صفوف الحضور.');
        }

        $attendance = Attendance::query()->where('uuid', $conflict->row_uuid)->first();

        if ($attendance === null) {
            throw new RuntimeException('صفّ الحضور المتنازع عليه لم يعد موجوداً.');
        }

        $session = $attendance->attendanceSession;

        if ($session === null) {
            throw new RuntimeException('جلسة الصفّ المتنازع عليه لم تعد موجودة.');
        }

        DB::transaction(function () use ($conflict, $attendance, $session, $reviewedBy): void {
            $this->takeAttendance->handle($session, [$attendance->student_id => $this->row($conflict)], $reviewedBy, amend: true);

            $conflict->update([
                'resolution' => 'client_wins',
                'reviewed_by' => $reviewedBy->id,
                'resolved_at' => now(),
            ]);
        });
    }

    /**
     * حمولةُ الجهاز بقيمها، **بلا** recorded_at الأصلي.
     *
     * وهذا مقصود: القلبُ كتابةٌ جديدة وقعت الآن بقرار إنسان، لا إحياءٌ لكتابةٍ قديمة.
     * لو أعدنا ختمها بزمن الجهاز القديم لبقيت أقدمَ من القيمة التي أزاحتها، فأوّلُ دفعةٍ
     * لاحقة من الجهاز الآخر تقلبها ثانيةً — ويصير قرارُ المشرف أضعفَ من دفعةٍ عمياء.
     *
     * @return array<string, mixed>
     */
    private function row(SyncConflict $conflict): array
    {
        $row = $conflict->client_payload ?? [];
        unset($row['recorded_at']);

        return $row;
    }
}
