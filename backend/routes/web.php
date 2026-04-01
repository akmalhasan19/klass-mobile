<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\AdminDashboardController;
use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome');

// --------------------------------------------------------------------------
// Admin — Route publik (login, tidak perlu autentikasi)
// --------------------------------------------------------------------------
Route::prefix('admin')
    ->name('admin.')
    ->group(function () {
        Route::get('/login', [AdminAuthController::class, 'showLogin'])->name('login');
        Route::post('/login', [AdminAuthController::class, 'login'])->name('login.post');
    });

// --------------------------------------------------------------------------
// Admin — Route terproteksi (melalui EnsureUserIsAdmin middleware)
// EnsureUserIsAdmin menangani: redirect ke login jika belum auth,
// atau abort 403 jika auth tapi bukan admin.
// --------------------------------------------------------------------------
Route::prefix('admin')
    ->name('admin.')
    ->middleware(['admin'])
    ->group(function () {
        Route::post('/logout', [AdminAuthController::class, 'logout'])->name('logout');

        Route::get('/', [AdminDashboardController::class, 'index'])->name('dashboard');
    });
