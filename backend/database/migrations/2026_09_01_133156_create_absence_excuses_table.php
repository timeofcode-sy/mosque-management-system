<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('absence_excuses', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('student_id')->constrained()->cascadeOnDelete();
            $table->date('from_date');
            $table->date('to_date');
            $table->string('reason');
            $table->string('attachment_path')->nullable();
            $table->foreignId('submitted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 24)->default('pending');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at', 3)->nullable();
            $table->text('review_note')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->index(['student_id', 'from_date', 'to_date']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('absence_excuses');
    }
};
