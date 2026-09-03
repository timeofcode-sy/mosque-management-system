<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * نقاط بند المنهج المحرَز، مجمّدةً بإعدادات لحظة التسجيل.
 *
 * achieved_on هو تاريخ آخر تحديث للبند — عليه تُصفّى النقاط بمدى زمني، لأن صفّ
 * التقدّم حالةٌ لا حدث، فلا يحمل تاريخاً بطبعه.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('student_curriculum_progress', function (Blueprint $table) {
            $table->decimal('points', 6, 2)->default(0)->after('score');
            $table->date('achieved_on')->nullable()->after('completed_on');

            $table->index(['student_id', 'achieved_on']);
        });
    }

    public function down(): void
    {
        Schema::table('student_curriculum_progress', function (Blueprint $table) {
            $table->dropIndex(['student_id', 'achieved_on']);
            $table->dropColumn(['points', 'achieved_on']);
        });
    }
};
