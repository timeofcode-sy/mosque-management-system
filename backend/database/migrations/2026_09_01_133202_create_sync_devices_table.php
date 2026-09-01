<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_devices', function (Blueprint $table) {
            $table->id();
            $table->uuid('device_uuid')->unique();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('app', 24);
            $table->unsignedBigInteger('last_pulled_seq')->default(0);
            $table->timestamp('last_pushed_at', 3)->nullable();
            $table->timestamp('last_pulled_at', 3)->nullable();
            $table->string('app_version', 32)->nullable();
            $table->string('platform', 32)->nullable();
            $table->timestamps(3);

            $table->index(['user_id', 'app']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_devices');
    }
};
