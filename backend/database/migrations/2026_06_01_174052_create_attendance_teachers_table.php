<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('attendance_teachers', function (Blueprint $table) {
            $table->id();

            $table->foreignId('circle_session_id')
                ->constrained('circle_sessions')
                ->cascadeOnDelete();

            $table->foreignId('teacher_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->string('status');

            $table->text('notes')->nullable();

            $table->timestamps();

            $table->unique([
                'circle_session_id',
                'teacher_id',
            ]);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('attendance_teachers');
    }
};
