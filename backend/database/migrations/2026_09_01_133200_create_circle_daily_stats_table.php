<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('circle_daily_stats', function (Blueprint $table) {
            $table->id();
            $table->foreignId('course_circle_id')->constrained()->cascadeOnDelete();
            $table->date('date');
            $table->unsignedSmallInteger('present')->default(0);
            $table->unsignedSmallInteger('absent')->default(0);
            $table->unsignedSmallInteger('late')->default(0);
            $table->unsignedSmallInteger('excused')->default(0);
            $table->unsignedSmallInteger('total')->default(0);
            $table->decimal('attendance_rate', 5, 2)->default(0);
            $table->unsignedSmallInteger('daily_rank_in_shift')->nullable();
            $table->timestamps(3);

            $table->unique(['course_circle_id', 'date']);
            $table->index('date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('circle_daily_stats');
    }
};
