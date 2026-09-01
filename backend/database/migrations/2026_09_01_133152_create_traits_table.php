<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('traits', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('slug', 64);
            $table->string('polarity', 16)->default('neutral');
            $table->string('color', 16)->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps(3);

            $table->unique(['institute_id', 'slug']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('traits');
    }
};
