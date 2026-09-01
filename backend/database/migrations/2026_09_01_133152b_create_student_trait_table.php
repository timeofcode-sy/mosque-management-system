<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('student_trait', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->foreignId('trait_id')->constrained('traits')->cascadeOnDelete();
            $table->foreignId('noted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('note')->nullable();
            $table->timestamps(3);

            $table->unique(['student_id', 'trait_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('student_trait');
    }
};
