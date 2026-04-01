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

Route::get('/', function () {
    return response()->json([
        'success' => true,
        'message' => 'Klass Mobile API is up and running!',
        'version' => '1.0.0'
    ]);
});

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
// Public Read-Only API Resources
// =========================================================================
Route::get('/topics', [TopicController::class, 'index']);
Route::get('/topics/{topic}', [TopicController::class, 'show']);
Route::get('/contents', [ContentController::class, 'index']);
Route::get('/contents/{content}', [ContentController::class, 'show']);
Route::get('/marketplace-tasks', [MarketplaceTaskController::class, 'index']);
Route::get('/marketplace-tasks/{marketplaceTask}', [MarketplaceTaskController::class, 'show']);
Route::get('/student-progress', [StudentProgressController::class, 'index']);
Route::get('/student-progress/{studentProgress}', [StudentProgressController::class, 'show']);

// =========================================================================
// App Config API (Public)
// =========================================================================
use App\Http\Controllers\Api\HomepageSectionController;

Route::get('/homepage-sections', [HomepageSectionController::class, 'index']);

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

    // Authenticated user project creation flow used by the mobile app.
    Route::post('/topics', [TopicController::class, 'store']);
});

// =========================================================================
// Admin-Protected Write Routes
// =========================================================================
Route::middleware(['auth:sanctum', 'admin'])->group(function () {
    Route::match(['put', 'patch'], '/topics/{topic}', [TopicController::class, 'update']);
    Route::delete('/topics/{topic}', [TopicController::class, 'destroy']);

    Route::post('/contents', [ContentController::class, 'store']);
    Route::match(['put', 'patch'], '/contents/{content}', [ContentController::class, 'update']);
    Route::delete('/contents/{content}', [ContentController::class, 'destroy']);

    Route::post('/marketplace-tasks', [MarketplaceTaskController::class, 'store']);
    Route::match(['put', 'patch'], '/marketplace-tasks/{marketplaceTask}', [MarketplaceTaskController::class, 'update']);
    Route::delete('/marketplace-tasks/{marketplaceTask}', [MarketplaceTaskController::class, 'destroy']);

    Route::post('/student-progress', [StudentProgressController::class, 'store']);
    Route::match(['put', 'patch'], '/student-progress/{studentProgress}', [StudentProgressController::class, 'update']);
    Route::delete('/student-progress/{studentProgress}', [StudentProgressController::class, 'destroy']);

    Route::post('/upload/{category}', [FileUploadController::class, 'upload'])
        ->where('category', 'avatars|gallery|materials|attachments');

    Route::delete('/upload/{category}', [FileUploadController::class, 'destroy'])
        ->where('category', 'avatars|gallery|materials|attachments');
});
