<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StudentProgress;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StudentProgressController extends Controller
{
    public function index(): JsonResponse
    {
        $progress = StudentProgress::orderByDesc('completion_date')->get();
        return response()->json(['data' => $progress]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'student_name'    => 'required|string|max:255',
            'score'           => 'required|integer|min:0|max:100',
            'completion_date' => 'nullable|date',
        ]);

        $progress = StudentProgress::create($validated);

        return response()->json(['data' => $progress], 201);
    }

    public function show(StudentProgress $studentProgress): JsonResponse
    {
        return response()->json(['data' => $studentProgress]);
    }

    public function update(Request $request, StudentProgress $studentProgress): JsonResponse
    {
        $validated = $request->validate([
            'student_name'    => 'sometimes|string|max:255',
            'score'           => 'sometimes|integer|min:0|max:100',
            'completion_date' => 'nullable|date',
        ]);

        $studentProgress->update($validated);

        return response()->json(['data' => $studentProgress]);
    }

    public function destroy(StudentProgress $studentProgress): JsonResponse
    {
        $studentProgress->delete();
        return response()->json(null, 204);
    }
}
