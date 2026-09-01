<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('memorization_logs', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->foreignId('course_circle_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('attendance_session_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('curriculum_item_id')->nullable()->constrained()->nullOnDelete();
            $table->date('date');
            $table->string('type', 24)->default('hifz');
            $table->unsignedTinyInteger('from_surah')->nullable();
            $table->unsignedSmallInteger('from_ayah')->nullable();
            $table->unsignedTinyInteger('to_surah')->nullable();
            $table->unsignedSmallInteger('to_ayah')->nullable();
            $table->decimal('pages', 5, 2)->nullable();
            $table->unsignedTinyInteger('memorization_score')->nullable();
            $table->unsignedTinyInteger('tajweed_score')->nullable();
            $table->unsignedSmallInteger('mistakes_count')->nullable();
            $table->foreignId('teacher_id')->nullable()->constrained()->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->index(['student_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('memorization_logs');
    }
};
