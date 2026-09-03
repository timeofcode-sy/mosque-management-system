<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * إسقاط حمولتين ميتتين:
 *
 * - report_templates: قوالب «نص جاهز للإرسال» بلا أي قناة إرسال في النظام.
 * - institutes.timezone: حقل يُكتب ولا يُقرأ؛ المنطقة الزمنية صارت واحدة للتطبيق
 *   كله في config/app.php (APP_TIMEZONE).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('report_templates');

        Schema::table('institutes', function (Blueprint $table) {
            $table->dropColumn('timezone');
        });
    }

    public function down(): void
    {
        Schema::table('institutes', function (Blueprint $table) {
            $table->string('timezone', 64)->default('Asia/Damascus');
        });

        Schema::create('report_templates', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->constrained()->cascadeOnDelete();
            $table->string('key', 64);
            $table->string('name');
            $table->string('scope', 24)->default('circle');
            $table->text('body');
            $table->boolean('is_active')->default(true);
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['institute_id', 'key']);
        });
    }
};
