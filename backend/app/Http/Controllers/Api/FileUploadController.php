<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\FileUploadRequest;
use App\Services\FileUploadService;
use Illuminate\Http\JsonResponse;

/**
 * FileUploadController
 *
 * Endpoint untuk upload file ke Supabase Storage bucket.
 * Mendukung kategori: avatars, gallery, materials, attachments.
 *
 * POST /api/upload/{category}
 */
class FileUploadController extends Controller
{
    public function __construct(
        protected FileUploadService $uploadService,
    ) {}

    /**
     * Upload file ke kategori yang ditentukan.
     *
     * @param  FileUploadRequest  $request
     * @param  string             $category  avatars|gallery|materials|attachments
     * @return JsonResponse
     */
    public function upload(FileUploadRequest $request, string $category): JsonResponse
    {
        try {
            $result = $this->uploadService->upload(
                $request->file('file'),
                $category,
            );

            return response()->json([
                'success' => true,
                'message' => 'File berhasil di-upload.',
                'data' => [
                    'path' => $result['path'],
                    'url' => $result['url'],
                    'category' => $category,
                ],
            ], 201);

        } catch (\InvalidArgumentException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 422);

        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal.',
                'errors' => $e->errors(),
            ], 422);

        } catch (\Throwable $e) {
            report($e);

            return response()->json([
                'success' => false,
                'message' => 'Gagal meng-upload file. Silakan coba lagi.',
            ], 500);
        }
    }

    /**
     * Hapus file dari bucket.
     *
     * DELETE /api/upload/{category}?path=avatars/1234_abc_photo.jpg
     */
    public function destroy(string $category, FileUploadService $uploadService): JsonResponse
    {
        $path = request()->query('path');

        if (!$path) {
            return response()->json([
                'success' => false,
                'message' => 'Parameter "path" wajib dikirim.',
            ], 422);
        }

        try {
            $deleted = $uploadService->delete($path);

            return response()->json([
                'success' => $deleted,
                'message' => $deleted ? 'File berhasil dihapus.' : 'File tidak ditemukan.',
            ], $deleted ? 200 : 404);

        } catch (\Throwable $e) {
            report($e);

            return response()->json([
                'success' => false,
                'message' => 'Gagal menghapus file. Silakan coba lagi.',
            ], 500);
        }
    }
}
