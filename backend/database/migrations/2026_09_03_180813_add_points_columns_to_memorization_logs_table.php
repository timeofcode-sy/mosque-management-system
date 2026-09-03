<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * أعمدة التسميع والنقاط على سجل الحفظ.
 *
 * الأسطر والنقاط تُجمَّد وقت التسجيل: تغيير إعدادات النقاط لاحقاً يجب ألّا يعيد
 * كتابة تاريخ الطلاب — وهي فلسفة circle_daily_stats نفسها (أرقام محسوبة مسبقاً).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('memorization_logs', function (Blueprint $table) {
            /** تقدير التسميع: ممتاز / جيد جداً / جيد */
            $table->string('grade', 16)->nullable()->after('type');

            /** أسطر المدى كاملاً — للعرض */
            $table->decimal('lines', 6, 2)->nullable()->after('pages');

            /** الأسطر الجديدة دون المكرّر — أساس احتساب النقاط */
            $table->decimal('new_lines', 6, 2)->nullable()->after('lines');

            /** النقاط الناتجة، مجمّدة بإعدادات لحظة التسجيل */
            $table->decimal('points', 6, 2)->default(0)->after('new_lines');

            /** الجزء المختار في الواجهة — للفلترة ولافتراض الجزء في التسميع التالي */
            $table->unsignedTinyInteger('juz')->nullable()->after('points');

            $table->index(['student_id', 'attendance_session_id']);
        });
    }

    public function down(): void
    {
        Schema::table('memorization_logs', function (Blueprint $table) {
            $table->dropIndex(['student_id', 'attendance_session_id']);
            $table->dropColumn(['grade', 'lines', 'new_lines', 'points', 'juz']);
        });
    }
};
