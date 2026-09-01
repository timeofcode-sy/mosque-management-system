<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('custom_field_values', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('custom_field_id')->constrained()->cascadeOnDelete();
            $table->morphs('entity');
            $table->json('value')->nullable();
            $table->timestamps(3);

            $table->unique(['custom_field_id', 'entity_type', 'entity_id'], 'custom_field_values_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('custom_field_values');
    }
};
