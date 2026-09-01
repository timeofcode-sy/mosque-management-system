<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shift_days', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('shift_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('weekday');
            $table->timestamps(3);

            $table->unique(['shift_id', 'weekday']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shift_days');
    }
};
