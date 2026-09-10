<?php

namespace App\Providers;

use App\Contracts\PushNotifier;
use App\Models\User;
use App\Notifications\FcmPushNotifier;
use App\Notifications\NullPushNotifier;
use App\Support\SyncRecorder;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
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
