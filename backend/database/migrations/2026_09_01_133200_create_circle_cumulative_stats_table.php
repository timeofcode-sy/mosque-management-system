<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('circle_cumulative_stats', function (Blueprint $table) {
            $table->id();
            $table->foreignId('course_circle_id')->constrained()->cascadeOnDelete();
            $table->date('as_of_date');
            $table->unsignedInteger('sessions_count')->default(0);
            $table->unsignedInteger('present')->default(0);
            $table->unsignedInteger('absent')->default(0);
            $table->unsignedInteger('late')->default(0);
            $table->unsignedInteger('excused')->default(0);
            $table->unsignedInteger('total')->default(0);
            $table->decimal('attendance_rate', 5, 2)->default(0);
            $table->unsignedSmallInteger('overall_rank_in_shift')->nullable();
            $table->timestamps(3);

            $table->unique(['course_circle_id', 'as_of_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('circle_cumulative_stats');
    }
};
