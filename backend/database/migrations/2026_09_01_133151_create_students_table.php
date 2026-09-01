<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('students', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->foreignId('institute_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();

            /** البيانات الأساسية والشخصية */
            $table->string('registration_no', 32)->nullable();
            $table->date('registration_date')->nullable();
            $table->string('registration_date_hijri', 24)->nullable();
            $table->string('photo_path')->nullable();
            $table->string('first_name');
            $table->string('father_name');
            $table->string('family_name');
            $table->date('birth_date')->nullable();
            $table->string('birth_place')->nullable();
            $table->string('gender', 8)->default('male');
            $table->string('national_id', 32)->nullable();
            $table->string('grade_level')->nullable();
            $table->string('student_job')->nullable();
            $table->string('phone', 32)->nullable();
            $table->string('permanent_address')->nullable();
            $table->string('current_address')->nullable();

            /** بيانات العائلة — تفاصيل الأب والأم في جدول guardians */
            $table->unsignedTinyInteger('family_members_count')->nullable();

            /** الحالة الصحية والاجتماعية */
            $table->text('student_health_status')->nullable();
            $table->text('family_health_status')->nullable();

            $table->string('status', 24)->default('active');
            $table->text('notes')->nullable();
            $table->timestamps(3);
            $table->softDeletes('deleted_at', 3);

            $table->unique(['institute_id', 'registration_no']);
            $table->index(['institute_id', 'status']);
            $table->index(['institute_id', 'family_name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('students');
    }
};
