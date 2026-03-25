<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketplaceTask;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MarketplaceTaskController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = MarketplaceTask::with('content');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        $tasks = $query->latest()->get();
        return response()->json(['data' => $tasks]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'content_id' => 'required|uuid|exists:contents,id',
            'status'     => 'sometimes|in:open,taken,done',
            'creator_id' => 'nullable|string|max:255',
        ]);

        $task = MarketplaceTask::create($validated);
        $task->load('content');

        return response()->json(['data' => $task], 201);
    }

    public function show(MarketplaceTask $marketplaceTask): JsonResponse
    {
        $marketplaceTask->load('content.topic');
        return response()->json(['data' => $marketplaceTask]);
    }

    public function update(Request $request, MarketplaceTask $marketplaceTask): JsonResponse
    {
        $validated = $request->validate([
            'status'     => 'sometimes|in:open,taken,done',
            'creator_id' => 'nullable|string|max:255',
        ]);

        $marketplaceTask->update($validated);

        return response()->json(['data' => $marketplaceTask]);
    }

    public function destroy(MarketplaceTask $marketplaceTask): JsonResponse
    {
        $marketplaceTask->delete();
        return response()->json(null, 204);
    }
}
