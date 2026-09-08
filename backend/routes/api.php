<?php

use App\Http\Controllers\Api\V1\Admin\CatalogController;
use App\Http\Controllers\Api\V1\Admin\InstituteAdminController;
use App\Http\Controllers\Api\V1\Admin\UserAdminController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BootstrapController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\GuardianController;
use App\Http\Controllers\Api\V1\InstituteController;
use App\Http\Controllers\Api\V1\StudentSelfController;
use App\Http\Controllers\Api\V1\SyncConflictController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Controllers\Api\V1\TeacherController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/devices/register', [DeviceController::class, 'register']);
    });

    Route::middleware(['auth:sanctum', 'institute.scope'])->group(function (): void {
        Route::get('/bootstrap', BootstrapController::class);

        /** مبدّل المعاهد في الديسكتوب — والاختيار يُرفق بعدها في ترويسة X-Institute */
        Route::get('/institutes', [InstituteController::class, 'index']);

        Route::middleware('permission:sync.pull')->get('/sync/pull', [SyncController::class, 'pull']);
        Route::middleware('permission:sync.push')->post('/sync/push', [SyncController::class, 'push']);

        /** التعارضات: جدولٌ لا يُزامَن، فيُقرأ مباشرةً ويُحكَم فيه متّصلاً — م.6.1 */
        Route::middleware('permission:conflicts.review')->group(function (): void {
            Route::get('/sync/conflicts', [SyncConflictController::class, 'index']);
            Route::post('/sync/conflicts/{uuid}/resolve', [SyncConflictController::class, 'resolve']);
        });

        /**
         * سطحُ الإدارة — ✅ م.6.2. كلُّها REST مباشر لا أنواعَ عملياتٍ في الطابور،
         * بقاعدة [PHASE-6-STAGES.MD §3.1]: ما هو متّصلٌ بطبعه (حسابٌ ودورٌ وكلمةُ
         * مرور، وبنيةُ دورةٍ تُهيَّأ مرّةً في الفصل) لا يُصفّ أوف-لاين. وما يُكتب في
         * المسجد بلا شبكة — تسجيلُ طالبٍ وتسجيلُه في حلقة والنقلُ ومراجعةُ الأعذار —
         * أنواعُ عملياتٍ في `sync/push` لا نقاطٌ هنا.
         *
         * والحارسُ صلاحيةٌ لكل باب لا دورٌ واحد للسطح كلِّه: الفرقُ بين المشرف ومديرِ
         * المعهد صلاحياتٌ لا نسخةُ برنامج ([APPS-FEATURES.md §4.1])، فالمشرفُ يبلغ
         * البطاقاتِ وكلماتِ المرور ولا يبلغ الحساباتِ ولا بنيةَ الدورة.
         */
        Route::prefix('/admin')->group(function (): void {
            Route::middleware('permission:settings.manage')
                ->put('/institute', [InstituteAdminController::class, 'updateCurrent']);

            Route::middleware('permission:institutes.manage')->group(function (): void {
                Route::post('/institutes', [InstituteAdminController::class, 'store']);
                Route::put('/institutes/{uuid}', [InstituteAdminController::class, 'update']);
            });

            Route::middleware('permission:users.manage')->group(function (): void {
                Route::get('/roles', [UserAdminController::class, 'roles']);
                Route::get('/users', [UserAdminController::class, 'index']);
                Route::post('/users/{user}/roles', [UserAdminController::class, 'assignRole']);
                Route::delete('/users/{user}/roles', [UserAdminController::class, 'revokeRole']);
                Route::post('/users/{user}/activation', [UserAdminController::class, 'activation']);
            });

            Route::middleware('permission:users.invite')->post('/users', [UserAdminController::class, 'store']);

            Route::middleware('permission:credentials.manage')
                ->post('/users/{user}/password', [UserAdminController::class, 'resetPassword']);

            Route::middleware('permission:credentials.export')
                ->get('/credentials', [UserAdminController::class, 'credentials']);

            Route::middleware('permission:courses.manage')->group(function (): void {
                Route::post('/courses', [CatalogController::class, 'storeCourse']);
                Route::put('/courses/{uuid}', [CatalogController::class, 'updateCourse']);
                Route::post('/courses/{uuid}/activate', [CatalogController::class, 'activateCourse']);
            });

            Route::middleware('permission:shifts.manage')->group(function (): void {
                Route::post('/shifts', [CatalogController::class, 'storeShift']);
                Route::put('/shifts/{uuid}', [CatalogController::class, 'updateShift']);
            });

            Route::middleware('permission:circles.manage')->group(function (): void {
                Route::post('/circles', [CatalogController::class, 'storeCircle']);
                Route::put('/circles/{uuid}', [CatalogController::class, 'updateCircle']);
                Route::post('/circles/{uuid}/run', [CatalogController::class, 'runCircle']);
            });
        });

        Route::middleware('role:teacher')->prefix('/teacher')->group(function (): void {
            Route::get('/circles', [TeacherController::class, 'circles']);
            Route::get('/sessions/{date}', [TeacherController::class, 'session']);
        });

        Route::middleware('role:guardian')->prefix('/guardian')->group(function (): void {
            Route::get('/children', [GuardianController::class, 'children']);
            Route::get('/children/{student}/attendance', [GuardianController::class, 'childAttendance']);
            Route::post('/excuses', [GuardianController::class, 'submitExcuse']);
        });

        Route::middleware('role:student')->prefix('/student')->group(function (): void {
            Route::get('/me/attendance', [StudentSelfController::class, 'attendance']);
            Route::get('/me/progress', [StudentSelfController::class, 'progress']);
        });
    });
});
