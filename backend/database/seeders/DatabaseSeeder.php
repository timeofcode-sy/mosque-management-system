<?php

namespace Database\Seeders;

use App\Support\SyncRecorder;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Artisan;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * التسجيل مُعطَّل أثناء البذر **للسرعة وحدها**: صفٌّ في change_log لكل صفٍّ يُبذَر
     * يضاعف زمن `migrate:fresh --seed` بلا داعٍ، والمراقبُ يستدعي `record()` صفّاً صفّاً.
     *
     * 🔴 م.5.3 — تصحيحُ حجّةٍ خاطئة: كان مكتوباً هنا أن «جهازاً جديداً يسحب من since=0
     * فيرى البذرة كاملةً على أي حال»، وهذا **غير صحيح**. `SyncPull` يقرأ change_log
     * وحده ولا يمسّ جداول الدومين، فالبذرةُ المكتومة كانت تبقى خفيّةً عن كل عميلٍ إلى
     * الأبد: التطبيق يدخل ويرى ثيم المعهد ثم يعرض شاشةً فارغة.
     *
     * فالتعطيل يبقى، ويُتبَع بالردم — والتيّارُ يخرج كاملاً بضربةٍ واحدة بدل 1200 كتابة
     * متفرّقة. وكونُه يجري في كل بذرة يمنع `sync:backfill-change-log` من أن يعطب صامتاً.
     */
    public function run(): void
    {
        app(SyncRecorder::class)->without(fn () => $this->call([
            RolesAndPermissionsSeeder::class,
            PersonalTraitSeeder::class,
            CurriculumSeeder::class,
            DemoInstituteSeeder::class,
        ]));

        Artisan::call('sync:backfill-change-log');
    }
}
