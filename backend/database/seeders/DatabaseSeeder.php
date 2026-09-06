<?php

namespace Database\Seeders;

use App\Support\SyncRecorder;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * البذر خارج تيّار التغييرات: قاعدةٌ تُبنى من الصفر ليست تغييراً يُبثّ، وجهازٌ
     * جديد يسحب من since=0 فيرى البذرة كاملةً على أي حال. ولولا التعطيل لأنتج
     * migrate:fresh --seed آلافَ صفوف change_log قبل أن يوجد جهازٌ واحد يقرؤها.
     */
    public function run(): void
    {
        app(SyncRecorder::class)->without(fn () => $this->call([
            RolesAndPermissionsSeeder::class,
            PersonalTraitSeeder::class,
            CurriculumSeeder::class,
            DemoInstituteSeeder::class,
        ]));
    }
}
