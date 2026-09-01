<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institutes', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->string('name');
            $table->string('short_name')->nullable();
            $table->string('logo_path')->nullable();
            $table->string('phone', 32)->nullable();
            $table->string('email')->nullable();
            $table->string('address')->nullable();
            $table->string('timezone', 64)->default('Asia/Damascus');
            $table->json('settings')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('institutes');
    }
};
