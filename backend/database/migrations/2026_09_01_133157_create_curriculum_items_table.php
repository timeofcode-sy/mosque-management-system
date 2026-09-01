<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('curriculum_items', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('curriculum_id')->constrained('curricula')->cascadeOnDelete();
            $table->string('name');
            $table->string('code', 64);
            $table->unsignedSmallInteger('sort_order')->default(0);

            /** بيانات إضافية حسب النوع: رقم الجزء، عدد الأبيات، عدد الأحاديث... */
            $table->json('meta')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps(3);

            $table->unique(['curriculum_id', 'code']);
            $table->index(['curriculum_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('curriculum_items');
    }
};
