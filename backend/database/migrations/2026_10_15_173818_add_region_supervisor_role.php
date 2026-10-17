<?php

use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * «مشرف معاهد» وصلاحيةُ «لوحة المعاهد» على القواعد القائمة.
 *
 * الأدوارُ تُبذر بـ RolesAndPermissionsSeeder يدوياً عند أول تشغيل، فلا يصل خادماً
 * قائماً دورٌ جديد إلا إن أُعيد تشغيله — وهنا يُعاد مع `migrate` نفسِه. والبذرةُ
 * متكرّرةٌ بلا أثر (findOrCreate ثم syncPermissions)، فتشغيلُها مرّةً أخرى آمن.
 */
return new class extends Migration
{
    public function up(): void
    {
        (new RolesAndPermissionsSeeder)->run();
    }

    public function down(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        Role::query()->where('name', 'region_supervisor')->delete();
        Permission::query()->where('name', 'institutes.overview')->delete();
    }
};
