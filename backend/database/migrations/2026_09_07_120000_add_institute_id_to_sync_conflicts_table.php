<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * التعارض صار يعرف معهده.
 *
 * الجدول بُني في المرحلة 4 بلا institute_id لأن شاشته كانت أداة مبرمج بلا نطاق
 * («التعارض يقع على مستوى الأجهزة لا المعاهد»). وقرار 2026-09-07 فتحها لمدير المعهد
 * والمشرف، وكلٌّ يرى معهده وحده — فصار العمود شرطَ حصرٍ لا حقلَ زينة.
 *
 * ولماذا عمودٌ لا ربطٌ عند القراءة؟ لأن الربط يمرّ بأربعة جداول
 * (attendances ← attendance_sessions ← course_circles ← circles)، ويكسر أول يوم
 * يحمل فيه الجدولُ صفّاً من جدولٍ آخر: table_name عمودٌ حرّ لا مفتاح.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sync_conflicts', function (Blueprint $table) {
            $table->foreignId('institute_id')->nullable()->after('id')->constrained()->cascadeOnDelete();
            $table->index(['institute_id', 'resolved_at']);
        });

        $this->backfill();
    }

    public function down(): void
    {
        Schema::table('sync_conflicts', function (Blueprint $table) {
            $table->dropIndex(['institute_id', 'resolved_at']);
            $table->dropConstrainedForeignId('institute_id');
        });
    }

    /**
     * الصفوف القائمة تُنسب إلى معاهدها بالربط الذي استغنينا عنه — مرّةً واحدة هنا.
     *
     * صفٌّ لا يُعثر على معهده (حذف الجلسة مثلاً) يبقى بـ null، ويظل مرئياً للمبرمج
     * وحده. والحلقة صريحة لا UPDATE...JOIN لأن التعارضات نادرة بحكم قيد
     * unique(session, student) — عشراتٌ لا آلاف.
     */
    private function backfill(): void
    {
        $rows = DB::table('sync_conflicts')->where('table_name', 'attendances')->get(['id', 'row_uuid']);

        foreach ($rows as $row) {
            $instituteId = DB::table('attendances')
                ->join('attendance_sessions', 'attendance_sessions.id', '=', 'attendances.attendance_session_id')
                ->join('course_circles', 'course_circles.id', '=', 'attendance_sessions.course_circle_id')
                ->join('circles', 'circles.id', '=', 'course_circles.circle_id')
                ->where('attendances.uuid', $row->row_uuid)
                ->value('circles.institute_id');

            if ($instituteId !== null) {
                DB::table('sync_conflicts')->where('id', $row->id)->update(['institute_id' => $instituteId]);
            }
        }
    }
};
