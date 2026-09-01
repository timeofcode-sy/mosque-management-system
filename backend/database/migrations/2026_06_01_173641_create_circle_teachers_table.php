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
        Schema::create('circle_teachers', function (Blueprint $table) {
            $table->id();

            $table->foreignId('circle_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->foreignId('teacher_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->string('role')->default('main_teacher');

            $table->date('joined_at')->nullable();

            $table->timestamps();

            $table->unique([
                'circle_id',
                'teacher_id',
            ]);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('circle_teachers');
    }
};
