<?php

namespace App\Providers;

use App\Models\User;
use App\Support\SyncRecorder;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

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
