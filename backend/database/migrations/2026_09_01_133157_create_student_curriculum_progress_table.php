<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('student_curriculum_progress', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->foreignId('curriculum_item_id')->constrained()->cascadeOnDelete();
            $table->foreignId('course_circle_id')->nullable()->constrained()->nullOnDelete();
            $table->string('status', 24)->default('not_started');
            $table->unsignedTinyInteger('percent')->default(0);
            $table->unsignedTinyInteger('score')->nullable();
            $table->date('started_on')->nullable();
            $table->date('completed_on')->nullable();
            $table->foreignId('teacher_id')->nullable()->constrained()->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['student_id', 'curriculum_item_id']);
            $table->index(['student_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('student_curriculum_progress');
    }
};
