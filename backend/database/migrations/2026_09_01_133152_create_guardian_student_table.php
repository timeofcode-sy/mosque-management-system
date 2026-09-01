<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('guardian_student', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('guardian_id')->constrained()->cascadeOnDelete();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->string('relation', 24)->default('father');
            $table->boolean('is_primary')->default(false);
            $table->boolean('can_view_reports')->default(true);
            $table->boolean('can_submit_excuses')->default(true);
            $table->timestamps(3);

            $table->unique(['guardian_id', 'student_id']);
            $table->index(['student_id', 'relation']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('guardian_student');
    }
};
