<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('course_circles', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('course_id')->constrained()->cascadeOnDelete();
            $table->foreignId('circle_id')->constrained()->cascadeOnDelete();
            $table->foreignId('shift_id')->constrained()->cascadeOnDelete();
            $table->string('room')->nullable();
            $table->unsignedSmallInteger('capacity')->nullable();
            $table->string('status', 24)->default('active');
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            /** الحلقة الواحدة تعمل في دوام واحد فقط ضمن الدورة */
            $table->unique(['course_id', 'circle_id']);
            $table->index(['shift_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('course_circles');
    }
};
