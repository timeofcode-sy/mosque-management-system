<?php

use App\Http\Controllers\ReportPrintController;
use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome')->name('home');

/**
 * كل مجموعة خلف صلاحيتها. لوحة المعلومات وحدها مفتوحة لكل مستخدم موثَّق لأن محتواها
 * مشتقّ من صلاحياته أصلاً — وما عداها كان مفتوحاً للجميع حتى الآن، بمن فيهم الطالب
 * وولي الأمر.
 *
 * مفتاح فريق Spatie يُضبط قبل هذه الفحوص في SetPanelInstituteScope الملحق بمجموعة web.
 */
Route::middleware(['auth', 'verified'])->group(function () {
    Route::livewire('dashboard', 'pages::dashboard')->name('dashboard');

    Route::middleware('permission:institutes.manage')->group(function () {
        Route::livewire('institutes', 'pages::institutes.index')->name('institutes.index');
        Route::livewire('institutes/overview', 'pages::institutes.overview')->name('institutes.overview');
        Route::livewire('institutes/create', 'pages::institutes.form')->name('institutes.create');
        Route::livewire('institutes/{institute}/edit', 'pages::institutes.form')->name('institutes.edit');
    });

    Route::middleware('permission:users.manage')->group(function () {
        Route::livewire('users', 'pages::users.index')->name('users.index');
    });

    Route::middleware('permission:system.debug')->group(function () {
        Route::livewire('system/sync-conflicts', 'pages::system.sync-conflicts')->name('system.conflicts');
        Route::livewire('system/devices', 'pages::system.devices')->name('system.devices');
        Route::livewire('system/change-log', 'pages::system.change-log')->name('system.change-log');
    });

    Route::middleware('permission:settings.manage')->group(function () {
        Route::livewire('institute', 'pages::institute.edit')->name('institute.edit');
        Route::livewire('settings/custom-fields', 'pages::custom-fields.index')->name('custom-fields.index');
        Route::livewire('settings/traits', 'pages::traits.index')->name('traits.index');
    });

    Route::middleware('permission:courses.manage')->group(function () {
        Route::livewire('courses', 'pages::courses.index')->name('courses.index');
        Route::livewire('shifts', 'pages::shifts.index')->name('shifts.index');
    });

    Route::middleware('permission:circles.manage')->group(function () {
        Route::livewire('circles', 'pages::circles.index')->name('circles.index');
        Route::livewire('circles/{courseCircle}', 'pages::circles.show')->name('circles.show');
    });

    /**
     * attendance.take لا attendance.view: الأخيرة يملكها الطالب وولي الأمر أيضاً (يريان
     * حضورهما في التطبيقات)، فلو حرست شاشات اللوحة لفتحت لوح تفقّد المعهد كلّه لطالب.
     * take هي بالضبط حدّ «طاقم المعهد».
     */
    Route::middleware('permission:attendance.take')->group(function () {
        Route::livewire('attendance', 'pages::attendance.index')->name('attendance.index');
        Route::livewire('attendance/{courseCircle}', 'pages::attendance.take')->name('attendance.take');
    });

    Route::livewire('excuses', 'pages::excuses.index')
        ->middleware('permission:excuses.review')
        ->name('excuses.index');

    Route::middleware('permission:students.manage')->group(function () {
        Route::livewire('students', 'pages::students.index')->name('students.index');
        Route::livewire('students/create', 'pages::students.form')->name('students.create');
        Route::livewire('students/{student}/edit', 'pages::students.form')->name('students.edit');
        Route::livewire('students/{student}', 'pages::students.show')->name('students.show');
    });

    Route::livewire('teachers', 'pages::teachers.index')
        ->middleware('permission:teachers.manage')
        ->name('teachers.index');

    Route::livewire('curricula', 'pages::curricula.index')
        ->middleware('permission:curricula.manage')
        ->name('curricula.index');

    Route::middleware('permission:reports.view')->group(function () {
        Route::livewire('reports', 'pages::reports.index')->name('reports.index');
        Route::livewire('stats', 'pages::stats.index')->name('stats.index');
        Route::get('reports/circle/{courseCircle}/print', [ReportPrintController::class, 'circleDaily'])->name('reports.print.circle');
        Route::get('reports/circle/{courseCircle}/points/print', [ReportPrintController::class, 'circlePoints'])->name('reports.print.points');
        Route::get('reports/shift/{shift}/print', [ReportPrintController::class, 'shiftRanking'])->name('reports.print.shift');
        Route::get('reports/student/{student}/print', [ReportPrintController::class, 'student'])->name('reports.print.student');
    });
});

require __DIR__.'/settings.php';
