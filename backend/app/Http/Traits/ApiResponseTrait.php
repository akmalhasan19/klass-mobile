<?php

namespace App\Http\Traits;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Http\Resources\Json\ResourceCollection;

/**
 * ApiResponseTrait
 *
 * Menyediakan format response JSON yang konsisten untuk semua API endpoint.
 *
 * Schema standar:
 * {
 *   "success": true|false,
 *   "message": "...",
 *   "data": { ... } | [ ... ],
 *   "meta": { ... }   // hanya untuk paginated response
 * }
 */
trait ApiResponseTrait
{
    /**
     * Response sukses dengan data.
     */
    protected function success(
        mixed $data = null,
        string $message = 'Berhasil.',
        int $code = 200,
    ): JsonResponse {
        $response = [
            'success' => true,
            'message' => $message,
            'data' => $data,
        ];

        return response()->json($response, $code);
    }

    /**
     * Response sukses untuk resource yang baru dibuat (201).
     */
    protected function created(
        mixed $data = null,
        string $message = 'Data berhasil dibuat.',
    ): JsonResponse {
        return $this->success($data, $message, 201);
    }

    /**
     * Response sukses untuk request async yang diterima (202).
     */
    protected function accepted(
        mixed $data = null,
        string $message = 'Permintaan diterima.',
    ): JsonResponse {
        return $this->success($data, $message, 202);
    }

    /**
     * Response sukses tanpa konten (204).
     */
    protected function noContent(string $message = 'Data berhasil dihapus.'): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
        ], 200); // 200 instead of 204 karena 204 tidak boleh punya body
    }

    /**
     * Response paginated menggunakan Laravel paginator.
     *
     * @param  \Illuminate\Pagination\LengthAwarePaginator  $paginator
     * @param  string|null  $resourceClass  Nama class API Resource (opsional)
     */
    protected function paginated(
        $paginator,
        ?string $resourceClass = null,
        string $message = 'Berhasil.',
    ): JsonResponse {
        $items = $resourceClass
            ? $resourceClass::collection($paginator->items())
            : $paginator->items();

        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $items,
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /**
     * Response error.
     */
    protected function error(
        string $message = 'Terjadi kesalahan.',
        int $code = 400,
        mixed $errors = null,
    ): JsonResponse {
        $response = [
            'success' => false,
            'message' => $message,
        ];

        if ($errors !== null) {
            $response['errors'] = $errors;
        }

        return response()->json($response, $code);
    }

    /**
     * Response not found (404).
     */
    protected function notFound(string $message = 'Data tidak ditemukan.'): JsonResponse
    {
        return $this->error($message, 404);
    }

    /**
     * Response unauthorized (401).
     */
    protected function unauthorized(string $message = 'Tidak memiliki akses.'): JsonResponse
    {
        return $this->error($message, 401);
    }

    /**
     * Response validation error (422).
     */
    protected function validationError(mixed $errors, string $message = 'Validasi gagal.'): JsonResponse
    {
        return $this->error($message, 422, $errors);
    }
}
