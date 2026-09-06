<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * الدخول صار باسم المستخدم لا بالبريد.
 *
 * الطالب وولي الأمر لا بريد لهما أصلاً، فبقاء البريد إلزامياً كان يمنع توليد
 * حساباتهما. وكلمة المرور تُحفظ مرّتين عمداً: مُلبَّدةً في password للمصادقة،
 * ومشفَّرةً في generated_password ليُعاد طبعها وتوزيعها — وهي تُمسح متى غيّر
 * صاحبُ الحساب كلمته بنفسه فلا يبقى للمشرف أثرٌ لما اختاره.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('username', 64)->nullable()->unique()->after('id');
            $table->text('generated_password')->nullable()->after('password');
            $table->boolean('is_active')->default(true)->after('generated_password');
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->string('email')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique(['username']);
            $table->dropColumn(['username', 'generated_password', 'is_active']);
        });
    }
};
