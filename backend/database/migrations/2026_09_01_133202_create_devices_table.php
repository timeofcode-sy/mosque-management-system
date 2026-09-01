<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('fcm_token', 512);
            $table->string('app', 24);
            $table->string('platform', 32)->nullable();
            $table->timestamp('last_seen_at', 3)->nullable();
            $table->timestamps(3);

            $table->index(['user_id', 'app']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('devices');
    }
};
