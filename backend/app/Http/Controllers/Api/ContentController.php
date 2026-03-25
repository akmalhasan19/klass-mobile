<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Content;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Content::with('topic');

        // Optional filter berdasarkan topic_id
        if ($request->has('topic_id')) {
            $query->where('topic_id', $request->topic_id);
        }

        $contents = $query->latest()->get();
        return response()->json(['data' => $contents]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'topic_id' => 'required|uuid|exists:topics,id',
            'type'     => 'required|in:module,quiz,brief',
            'data'     => 'nullable|array',
        ]);

        $content = Content::create($validated);
        $content->load('topic');

        return response()->json(['data' => $content], 201);
    }

    public function show(Content $content): JsonResponse
    {
        $content->load(['topic', 'tasks']);
        return response()->json(['data' => $content]);
    }

    public function update(Request $request, Content $content): JsonResponse
    {
        $validated = $request->validate([
            'topic_id' => 'sometimes|uuid|exists:topics,id',
            'type'     => 'sometimes|in:module,quiz,brief',
            'data'     => 'nullable|array',
        ]);

        $content->update($validated);

        return response()->json(['data' => $content]);
    }

    public function destroy(Content $content): JsonResponse
    {
        $content->delete();
        return response()->json(null, 204);
    }
}
