<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('evaluations', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->foreignId('course_circle_id')->nullable()->constrained()->nullOnDelete();
            $table->string('period', 24)->default('monthly');
            $table->date('period_start');
            $table->date('period_end');
            $table->unsignedTinyInteger('behavior')->nullable();
            $table->unsignedTinyInteger('commitment')->nullable();
            $table->unsignedTinyInteger('memorization')->nullable();
            $table->unsignedTinyInteger('tajweed')->nullable();
            $table->unsignedSmallInteger('total')->nullable();
            $table->foreignId('teacher_id')->nullable()->constrained()->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->index(['student_id', 'period_start']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('evaluations');
    }
};
