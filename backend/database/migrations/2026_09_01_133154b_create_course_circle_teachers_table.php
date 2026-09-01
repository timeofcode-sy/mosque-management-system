<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('course_circle_teachers', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('course_circle_id')->constrained()->cascadeOnDelete();
            $table->foreignId('teacher_id')->constrained()->cascadeOnDelete();
            $table->string('role', 24)->default('main');
            $table->date('joined_on')->nullable();
            $table->date('left_on')->nullable();
            $table->timestamps(3);

            $table->unique(['course_circle_id', 'teacher_id']);
            $table->index(['teacher_id', 'role']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('course_circle_teachers');
    }
};
