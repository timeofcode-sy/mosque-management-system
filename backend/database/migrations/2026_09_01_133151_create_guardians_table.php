<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('guardians', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('full_name');
            $table->string('phone', 32)->nullable();
            $table->string('alternate_phone', 32)->nullable();
            $table->string('occupation')->nullable();
            $table->string('national_id', 32)->nullable();
            $table->string('address')->nullable();
            $table->boolean('is_alive')->default(true);
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->index(['institute_id', 'phone']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('guardians');
    }
};
