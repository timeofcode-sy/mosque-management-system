<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BootstrapController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\GuardianController;
use App\Http\Controllers\Api\V1\StudentSelfController;
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

        Route::middleware('permission:sync.pull')->get('/sync/pull', [SyncController::class, 'pull']);
        Route::middleware('permission:sync.push')->post('/sync/push', [SyncController::class, 'push']);

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
