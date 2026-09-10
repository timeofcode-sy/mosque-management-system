<?php

namespace App\Providers;

use App\Contracts\PushNotifier;
use App\Models\User;
use App\Notifications\FcmPushNotifier;
use App\Notifications\NullPushNotifier;
use App\Support\SyncRecorder;
use Carbon\CarbonImmutable;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;
use Kreait\Firebase\Contract\Messaging;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // سياق تسجيل التغييرات حالةُ طلبٍ لا حالةُ نموذج: SyncPush يضبطه مرّة لكل عملية،
        // ومراقبُ RecordsSyncChanges يقرؤه من حيث لا يملك تمرير وسيط. ولذلك نسخةٌ واحدة.
        $this->app->singleton(SyncRecorder::class);

        $this->bindPushNotifier();
    }

    /**
     * قناةُ الإشعار الفوري — ✅ م.7.4.
     *
     * 🔑 **تُختار بوجود بيانات الاعتماد لا بعلَمٍ يدوي**: معهدٌ بلا حساب Firebase
     * يعمل كاملاً بقناةٍ صامتة، ولا يحتاج أحدٌ أن يتذكّر إطفاء مفتاحٍ ثانٍ. وعلَمٌ
     * منفصل عن الواقع يعني حالتين تفترقان — `FIREBASE_ENABLED=true` وبلا ملفّ
     * اعتماد ⇒ استثناءٌ عند أوّل غيابٍ يُسجَّل.
     *
     * والملفُّ يُفحَص وجودُه لا اسمُه: مسارٌ مضبوطٌ في `.env` إلى ملفٍّ لم يُنسَخ
     * إلى الخادم هو بالضبط الحالةُ التي تقع عند النشر.
     */
    private function bindPushNotifier(): void
    {
        $this->app->bind(PushNotifier::class, function (): PushNotifier {
            $credentials = config('firebase.projects.app.credentials');

            if (! is_string($credentials) || ! is_file(base_path($credentials)) && ! is_file($credentials)) {
                return new NullPushNotifier;
            }

            return new FcmPushNotifier($this->app->make(Messaging::class));
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureDefaults();
        $this->configureGlobalRoles();
        $this->configureRateLimits();
    }

    /**
     * Configure default behaviors for production-ready applications.
     */
    protected function configureDefaults(): void
    {
        Date::use(CarbonImmutable::class);

        DB::prohibitDestructiveCommands(
            app()->isProduction(),
        );

        Password::defaults(fn (): ?Password => app()->isProduction()
            ? Password::min(12)
                ->mixedCase()
                ->letters()
                ->numbers()
                ->symbols()
                ->uncompromised()
            : null,
        );
    }

    /**
     * السقفُ الخارجي على `POST /auth/login` — ✅ م.9.1.
     *
     * 🔑 **غايتُه غيرُ غايةِ القفل في `AuthController`.** ذاك يمنع التخمينَ على
     * حساب، وهذا يمنع **الإغراق**: `bcrypt` باثنتي عشرة جولة يكلّف الخادمَ نحوَ
     * عُشر ثانيةٍ لكل محاولة، فنقطةُ دخولٍ بلا سقفٍ سلاحُ استنزافٍ للمعالج
     * لا يحتاج صاحبُه أن يعرف اسمَ حسابٍ واحد.
     *
     * 🔑 **وستّون في الدقيقة لا خمس.** المعهدُ كلُّه خلف عنوانٍ واحد (شبكةُ
     * المسجد)، فالسقفُ الضيّق ههنا يقفل الجماعةَ لا المهاجم. وستّون تعلو فوق كلِّ
     * استعمالٍ بشريٍّ محتمَل — حتى يومَ التسجيل حين يدخل الطلابُ معاً — وتُبقي
     * الكلفةَ القصوى ستَّ ثوانٍ من المعالج في الدقيقة.
     *
     * 🔴 **واسمُه `api-login` لا `login`.** الاسمُ الثاني مأخوذٌ: فورتيفاي يسجّله
     * لدخول اللوحة بخمسٍ في الدقيقة، و[FortifyServiceProvider] يُقلع **بعد** هذا
     * المزوّد (`bootstrap/providers.php`)، فتسجيلُه يطمس تسجيلَنا بلا تحذيرٍ ولا
     * خطأ — `RateLimiter::for` استبدالٌ صامت لا إضافة.
     *
     * 🔑 **والخطرُ في أن الطمسَ يُبقي القفلَ عاملاً ويُضعفه**: كِلا التسجيلين
     * يقفل، فاختبارُ «هل يُقفَل بعد خمس؟» يمرّ في الحالتين. لكنّ نافذة فورتيفاي
     * **دقيقةٌ** ونافذتَنا **ربعُ ساعة**، فالطمسُ يعطي المهاجمَ ثلاثمئة محاولةٍ
     * في الساعة بدل عشرين — إضعافٌ خمسةَ عشرَ ضعفاً لا يُسقط اختباراً واحداً.
     * وكشفه أن الرسالة العائدة كانت رسالةَ لارافيل العامّة لا «أعِد المحاولة بعد
     * ربع ساعة» التي يكتبها [AuthController]: **النصُّ هو الذي دلّ على أنّ
     * الحارسَ غيرُ الحارس.**
     */
    protected function configureRateLimits(): void
    {
        RateLimiter::for('api-login', fn (Request $request) => Limit::perMinute(60)->by($request->ip()));
    }

    /**
     * المبرمج والمشرف الأعلى فوق نطاق المعاهد.
     *
     * أدوارهما مسنَدة خارج كل معهد (User::GLOBAL_TEAM_ID) فلا تراها فحوص spatie
     * المقيّدة بالمعهد الحالي، ومن ثمّ لا سبيل إليها إلا من هنا.
     *
     * إرجاع null لا false أمرٌ جوهري: false من Gate::before ينهي الفحص ويمنع الجميع،
     * بينما null يعني «لا رأي لي» فيتابع الفحص طريقه المعتاد.
     *
     * وحدها system.debug تسقط إلى الفحص المعتاد للمشرف الأعلى — أدوات المبرمج له وحده،
     * وهذا هو الفرق الوحيد بين الدورين.
     */
    protected function configureGlobalRoles(): void
    {
        Gate::before(function (User $user, string $ability): ?bool {
            if ($user->hasGlobalRole('developer')) {
                return true;
            }

            if ($user->hasGlobalRole('super_admin') && $ability !== 'system.debug') {
                return true;
            }

            return null;
        });
    }
}
