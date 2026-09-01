<?php

use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome')->name('home');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::livewire('dashboard', 'pages::dashboard')->name('dashboard');

    Route::livewire('institute', 'pages::institute.edit')->name('institute.edit');

    Route::livewire('courses', 'pages::courses.index')->name('courses.index');
    Route::livewire('shifts', 'pages::shifts.index')->name('shifts.index');

    Route::livewire('circles', 'pages::circles.index')->name('circles.index');
    Route::livewire('circles/{courseCircle}', 'pages::circles.show')->name('circles.show');

    Route::livewire('students', 'pages::students.index')->name('students.index');
    Route::livewire('students/create', 'pages::students.form')->name('students.create');
    Route::livewire('students/{student}/edit', 'pages::students.form')->name('students.edit');
    Route::livewire('students/{student}', 'pages::students.show')->name('students.show');

    Route::livewire('teachers', 'pages::teachers.index')->name('teachers.index');

    Route::livewire('curricula', 'pages::curricula.index')->name('curricula.index');

    Route::livewire('settings/custom-fields', 'pages::custom-fields.index')->name('custom-fields.index');
    Route::livewire('settings/traits', 'pages::traits.index')->name('traits.index');
});

require __DIR__.'/settings.php';
