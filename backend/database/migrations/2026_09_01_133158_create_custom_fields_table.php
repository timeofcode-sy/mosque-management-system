<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('custom_fields', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->constrained()->cascadeOnDelete();
            $table->string('entity', 32);
            $table->string('key', 64);
            $table->string('label');
            $table->string('type', 24)->default('text');
            $table->json('options')->nullable();
            $table->string('group')->nullable();
            $table->boolean('is_required')->default(false);
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['institute_id', 'entity', 'key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('custom_fields');
    }
};
