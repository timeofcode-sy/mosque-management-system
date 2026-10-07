<?php

use App\Http\Middleware\EnsureUserIsActive;
use App\Http\Middleware\SetApiInstituteScope;
use App\Http\Middleware\SetPanelInstituteScope;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Spatie\Permission\Middleware\PermissionMiddleware;
use Spatie\Permission\Middleware\RoleMiddleware;
use Spatie\Permission\Middleware\RoleOrPermissionMiddleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => RoleMiddleware::class,
            'permission' => PermissionMiddleware::class,
            'role_or_permission' => RoleOrPermissionMiddleware::class,
            'institute.scope' => SetApiInstituteScope::class,
        ]);

        /** يضبط مفتاح فريق Spatie قبل middleware الصلاحيات على كل طلبات اللوحة */
        $middleware->appendToGroup('web', SetPanelInstituteScope::class);

        /** الحساب المقفل لا تنفعه جلسةٌ قائمة ولا رمزٌ سابق */
        $middleware->appendToGroup('web', EnsureUserIsActive::class);
        $middleware->appendToGroup('api', EnsureUserIsActive::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );

        /**
         * ✅ م.9.1 — «Too Many Attempts.» لا تُقرأ على شاشةِ أبٍ عربية.
         *
         * السقفُ في `throttle:login` من صنع لارافيل، ونصُّه إنجليزيٌّ ثابت. وكلُّ
         * ما يقوله العميلُ للمستخدم يأتي من الخادم (`messageFor`)، فالتعريبُ
         * ههنا لا في التطبيقات الأربعة.
         */
        $exceptions->render(function (ThrottleRequestsException $exception, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return response()->json(
                ['message' => 'حاولتَ مراراً. أمهِل قليلاً ثم أعد المحاولة.'],
                429,
                $exception->getHeaders(),
            );
        });
    })->create();
