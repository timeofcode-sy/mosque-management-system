<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('students', function (Blueprint $table) {
            $table->id();

            $table->string('registration_number')->unique();
            $table->string('id_number')->unique()->nullable();

            $table->string('first_name');
            $table->string('last_name');
            $table->string('father_name')->nullable();

            $table->date('birth_date')->nullable();
            $table->string('birth_place')->nullable();
            $table->string('gender')->nullable();

            $table->string('photo_url')->nullable();

            $table->string('father_job')->nullable();
            $table->string('father_phone')->nullable();

            $table->string('mother_name')->nullable();
            $table->string('mother_job')->nullable();
            $table->string('mother_phone')->nullable();

            $table->unsignedInteger('siblings_count')->nullable();

            $table->text('primary_address')->nullable();
            $table->text('current_address')->nullable();

            $table->text('health_status')->nullable();
            $table->text('family_health_status')->nullable();

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('students');
    }
};
