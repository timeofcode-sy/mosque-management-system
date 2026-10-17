<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * وصفُ الجهاز لإحصاءات المطوّر: نوعُه وصانعُه وطرازُه ونظامُه وشاشتُه ونسخةُ التطبيق —
 * يرسلها التطبيقُ مع تسجيل الجهاز، ولا شيءَ منها يعرّف صاحبَه.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sync_devices', function (Blueprint $table) {
            $table->unsignedInteger('app_build')->nullable()->after('app_version');
            $table->string('device_type', 16)->nullable()->after('platform');
            $table->string('manufacturer', 64)->nullable()->after('device_type');
            $table->string('brand', 64)->nullable()->after('manufacturer');
            $table->string('model', 96)->nullable()->after('brand');
            $table->string('os_version', 64)->nullable()->after('model');
            $table->unsignedSmallInteger('sdk_int')->nullable()->after('os_version');
            $table->string('screen', 16)->nullable()->after('sdk_int');
            $table->string('locale', 16)->nullable()->after('screen');
            $table->unsignedInteger('memory_mb')->nullable()->after('locale');
            $table->boolean('is_physical')->nullable()->after('memory_mb');
        });
    }

    public function down(): void
    {
        Schema::table('sync_devices', function (Blueprint $table) {
            $table->dropColumn([
                'app_build', 'device_type', 'manufacturer', 'brand', 'model', 'os_version',
                'sdk_int', 'screen', 'locale', 'memory_mb', 'is_physical',
            ]);
        });
    }
};
