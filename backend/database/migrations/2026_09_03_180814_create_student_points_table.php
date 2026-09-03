<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * النقاط التقديرية: ما يمنحه الأستاذ أو المشرف بيده خارج الحساب الآلي.
 *
 * تقبل السالب (المشاغبة) والموجب (المشاركة والمسابقات)، وقد ترتبط بجلسة أو تستقلّ عنها.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('student_points', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->foreignId('course_circle_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('attendance_session_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('points', 6, 2);
            $table->string('reason', 32);
            $table->text('note')->nullable();
            $table->foreignId('awarded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->date('awarded_on');
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->index(['student_id', 'awarded_on']);
            $table->index(['student_id', 'attendance_session_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('student_points');
    }
};
