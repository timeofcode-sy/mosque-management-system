<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('student_transfers', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->foreignId('course_id')->constrained()->cascadeOnDelete();
            $table->foreignId('from_course_circle_id')->nullable()->constrained('course_circles')->nullOnDelete();
            $table->foreignId('to_course_circle_id')->nullable()->constrained('course_circles')->nullOnDelete();
            $table->date('transferred_on');
            $table->string('reason')->nullable();
            $table->foreignId('performed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps(3);

            $table->index(['student_id', 'transferred_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('student_transfers');
    }
};
