<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Topic;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TopicController extends Controller
{
    /**
     * Menampilkan semua topics (dengan contents).
     */
    public function index(): JsonResponse
    {
        $topics = Topic::with('contents')->latest()->get();
        return response()->json(['data' => $topics]);
    }

    /**
     * Menyimpan topic baru.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title'      => 'required|string|max:255',
            'teacher_id' => 'required|string|max:255',
        ]);

        $topic = Topic::create($validated);

        return response()->json(['data' => $topic], 201);
    }

    /**
     * Menampilkan detail satu topic.
     */
    public function show(Topic $topic): JsonResponse
    {
        $topic->load('contents.tasks');
        return response()->json(['data' => $topic]);
    }

    /**
     * Mengupdate topic.
     */
    public function update(Request $request, Topic $topic): JsonResponse
    {
        $validated = $request->validate([
            'title'      => 'sometimes|string|max:255',
            'teacher_id' => 'sometimes|string|max:255',
        ]);

        $topic->update($validated);

        return response()->json(['data' => $topic]);
    }

    /**
     * Menghapus topic.
     */
    public function destroy(Topic $topic): JsonResponse
    {
        $topic->delete();
        return response()->json(null, 204);
    }
}
