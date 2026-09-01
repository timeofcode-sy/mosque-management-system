<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('report_exports', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->constrained()->cascadeOnDelete();
            $table->string('type', 64);
            $table->json('params')->nullable();
            $table->string('file_path')->nullable();
            $table->string('status', 24)->default('pending');
            $table->foreignId('generated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('generated_at', 3)->nullable();
            $table->timestamps(3);

            $table->index(['institute_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('report_exports');
    }
};
