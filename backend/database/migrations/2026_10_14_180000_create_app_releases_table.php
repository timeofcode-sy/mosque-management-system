<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * `app_releases`: إصداراتُ التطبيقات كما ينشرها المبرمج، ويسأل عنها كلُّ تطبيقٍ عند فتحه.
     *
     * رقمُ البناء (`build_number`) هو وحده ما يُقارَن — أندرويد لا يثبّت نسخةً فوق أعلى منها رقماً،
     * و`version` نصٌّ للقارئ (`1.0.0-beta.6`). والملفُّ إمّا مرفوعٌ إلى الخادم (`file_path`
     * مع حجمه وبصمته) وإمّا رابطٌ خارجي (`external_url`).
     *
     * `app_installs`: آخرُ ما أبلغ به كلُّ جهازٍ عن نسخته حين سأل عن التحديث — قبل الدخول وبعده،
     * فيعرف المبرمج كم جهازاً بقي على نسخةٍ قديمة.
     */
    public function up(): void
    {
        Schema::create('app_releases', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('target', 24);
            $table->string('version', 32);
            $table->unsignedInteger('build_number');
            $table->string('title')->nullable();
            $table->text('notes')->nullable();
            $table->boolean('is_mandatory')->default(false);
            $table->string('file_path')->nullable();
            $table->string('file_name')->nullable();
            $table->unsignedBigInteger('file_size')->nullable();
            $table->char('sha256', 64)->nullable();
            $table->string('external_url', 2048)->nullable();
            $table->unsignedInteger('downloads')->default(0);
            $table->timestamp('published_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['target', 'build_number']);
            $table->index(['target', 'published_at']);
        });

        Schema::create('app_installs', function (Blueprint $table) {
            $table->id();
            $table->uuid('device_uuid');
            $table->string('target', 24);
            $table->unsignedInteger('build_number');
            $table->string('version', 32)->nullable();
            $table->timestamp('last_checked_at');
            $table->timestamps();

            $table->unique(['device_uuid', 'target']);
            $table->index(['target', 'last_checked_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_installs');
        Schema::dropIfExists('app_releases');
    }
};
