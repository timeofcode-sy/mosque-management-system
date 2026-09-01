<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('courses', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->date('starts_on');
            $table->date('ends_on')->nullable();
            $table->string('status', 24)->default('draft');
            $table->boolean('is_current')->default(false);
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->index(['institute_id', 'status']);
            $table->index(['institute_id', 'is_current']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('courses');
    }
};
