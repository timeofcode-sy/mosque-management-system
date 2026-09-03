<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * نوع ملاحظة التفقّد: إيجابية أو سلبية.
 *
 * عليه يُبنى مقياس «الأدب» في شاشة الإحصائيات — بدونه لا معنى لـ«أكثر الملاحظات الإيجابية».
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('attendances', function (Blueprint $table) {
            $table->string('note_polarity', 8)->nullable()->after('note');
        });
    }

    public function down(): void
    {
        Schema::table('attendances', function (Blueprint $table) {
            $table->dropColumn('note_polarity');
        });
    }
};
