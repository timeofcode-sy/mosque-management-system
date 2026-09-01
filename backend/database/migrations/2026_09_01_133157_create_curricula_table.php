<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('curricula', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('slug', 64);
            $table->string('type', 24)->default('custom');
            $table->text('description')->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['institute_id', 'slug']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('curricula');
    }
};
