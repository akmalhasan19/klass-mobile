<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AvatarController;
use App\Http\Controllers\Api\ContentController;
use App\Http\Controllers\Api\FileUploadController;
use App\Http\Controllers\Api\GalleryController;
use App\Http\Controllers\Api\MarketplaceTaskController;
use App\Http\Controllers\Api\StudentProgressController;
use App\Http\Controllers\Api\TopicController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Klass API Routes
|--------------------------------------------------------------------------
| Semua route di-prefix dengan /api secara otomatis oleh Laravel.
|
| Struktur:
|   - Public routes (auth)
|   - Protected routes (require Sanctum token)
|   - File upload routes
*/

// =========================================================================
// Auth Routes (Public)
// =========================================================================
Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);

    // Protected auth routes
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
    });
});

// =========================================================================
// Public API Resources (accessible without auth for now)
// =========================================================================
Route::apiResource('topics', TopicController::class);
Route::apiResource('contents', ContentController::class);
Route::apiResource('marketplace-tasks', MarketplaceTaskController::class);
Route::apiResource('student-progress', StudentProgressController::class);

// =========================================================================
// Gallery (Public — read-only list of media-rich content)
// =========================================================================
Route::get('/gallery', [GalleryController::class, 'index']);

// =========================================================================
// Protected Routes (require Sanctum auth)
// =========================================================================
Route::middleware('auth:sanctum')->group(function () {
    // Avatar Upload
    Route::post('/user/avatar', [AvatarController::class, 'store']);
});

// =========================================================================
// File Upload Routes
// =========================================================================
Route::post('/upload/{category}', [FileUploadController::class, 'upload'])
    ->where('category', 'avatars|gallery|materials|attachments');

Route::delete('/upload/{category}', [FileUploadController::class, 'destroy'])
    ->where('category', 'avatars|gallery|materials|attachments');
