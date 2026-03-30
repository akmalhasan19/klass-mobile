<?php

use App\Http\Controllers\Api\ContentController;
use App\Http\Controllers\Api\FileUploadController;
use App\Http\Controllers\Api\MarketplaceTaskController;
use App\Http\Controllers\Api\StudentProgressController;
use App\Http\Controllers\Api\TopicController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Klass API Routes
|--------------------------------------------------------------------------
| Semua route di-prefix dengan /api secara otomatis oleh Laravel.
| Route yang dilindungi Sanctum dibungkus middleware auth:sanctum.
*/

// Public route — info user yang sedang login
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// RESTful API Resources
Route::apiResource('topics', TopicController::class);
Route::apiResource('contents', ContentController::class);
Route::apiResource('marketplace-tasks', MarketplaceTaskController::class);
Route::apiResource('student-progress', StudentProgressController::class);

/*
|--------------------------------------------------------------------------
| File Upload Routes
|--------------------------------------------------------------------------
| POST   /api/upload/{category}  — Upload file (category: avatars, gallery, materials, attachments)
| DELETE /api/upload/{category}  — Hapus file (query param: path)
*/
Route::post('/upload/{category}', [FileUploadController::class, 'upload'])
    ->where('category', 'avatars|gallery|materials|attachments');

Route::delete('/upload/{category}', [FileUploadController::class, 'destroy'])
    ->where('category', 'avatars|gallery|materials|attachments');
