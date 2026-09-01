<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_sessions', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('course_circle_id')->constrained()->cascadeOnDelete();
            $table->date('session_date');
            $table->string('status', 24)->default('draft');
            $table->foreignId('opened_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('taken_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('completed_at', 3)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['course_circle_id', 'session_date']);
            $table->index(['session_date', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_sessions');
    }
};
