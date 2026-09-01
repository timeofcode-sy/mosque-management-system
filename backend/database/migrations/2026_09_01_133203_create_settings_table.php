<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institute_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('key', 96);
            $table->json('value')->nullable();
            $table->timestamps(3);

            $table->unique(['institute_id', 'key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('settings');
    }
};
