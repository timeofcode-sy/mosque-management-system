<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('enrollments', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('course_circle_id')->constrained()->cascadeOnDelete();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('status', 24)->default('active');
            $table->date('enrolled_on');
            $table->date('left_on')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['course_circle_id', 'student_id']);
            $table->index(['student_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('enrollments');
    }
};
