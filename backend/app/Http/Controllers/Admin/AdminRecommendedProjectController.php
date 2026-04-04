<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\RecommendedProject;
use App\Services\DocumentPreviewService;
use App\Services\FileUploadService;
use Illuminate\Http\Request;

class AdminRecommendedProjectController extends Controller
{
    protected FileUploadService $fileUploadService;
    protected DocumentPreviewService $previewService;

    public function __construct(FileUploadService $fileUploadService, DocumentPreviewService $previewService)
    {
        $this->fileUploadService = $fileUploadService;
        $this->previewService = $previewService;
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'ratio' => 'required|string',
            'project_type' => 'nullable|string',
            'tags' => 'nullable|string',
            'modules' => 'nullable|string',
            'thumbnail' => 'nullable|image|max:5120',
            'project_file' => 'nullable|file|mimes:pdf,ppt,pptx,doc,docx|max:10240',
            'display_priority' => 'nullable|integer',
            'is_active' => 'boolean',
            'starts_at' => 'nullable|date',
            'ends_at' => 'nullable|date|after_or_equal:starts_at',
        ]);

        $thumbnailUrl = null;
        if ($request->hasFile('thumbnail')) {
            $upload = $this->fileUploadService->upload($request->file('thumbnail'), 'gallery');
            $thumbnailUrl = $upload['url'];
        }

        $projectFileUrl = null;
        if ($request->hasFile('project_file')) {
            $upload = $this->fileUploadService->upload($request->file('project_file'), 'materials');
            $projectFileUrl = $upload['url'];

            // Fallback: Generate thumbnail preview from document if thumbnail is not provided
            if (!$thumbnailUrl) {
                $previewFile = $this->previewService->generatePreview($request->file('project_file'));
                if ($previewFile) {
                    $previewUpload = $this->fileUploadService->upload($previewFile, 'gallery');
                    $thumbnailUrl = $previewUpload['url'];
                    @unlink($previewFile->getRealPath()); // Clean up temp file
                }
            }
        }

        $project = RecommendedProject::create([
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'ratio' => $validated['ratio'] ?? '16:9',
            'project_type' => $validated['project_type'] ?? null,
            'tags' => !empty($validated['tags']) ? array_map('trim', explode(',', $validated['tags'])) : null,
            'modules' => !empty($validated['modules']) ? array_map('trim', explode(',', $validated['modules'])) : null,
            'thumbnail_url' => $thumbnailUrl,
            'project_file_url' => $projectFileUrl,
            'source_type' => RecommendedProject::SOURCE_ADMIN_UPLOAD,
            'display_priority' => $validated['display_priority'] ?? 0,
            'is_active' => $request->has('is_active'),
            'starts_at' => $validated['starts_at'] ?? null,
            'ends_at' => $validated['ends_at'] ?? null,
            'created_by' => auth()->id(),
            'updated_by' => auth()->id(),
        ]);

        ActivityLog::create([
            'actor_id' => auth()->id(),
            'action' => 'create_recommended_project',
            'subject_type' => RecommendedProject::class,
            'subject_id' => $project->id,
            'metadata' => ['title' => $project->title],
        ]);

        return back()->with('success', 'Recommended Project created successfully.');
    }

    public function update(Request $request, RecommendedProject $recommendedProject)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'ratio' => 'required|string',
            'project_type' => 'nullable|string',
            'tags' => 'nullable|string',
            'modules' => 'nullable|string',
            'thumbnail' => 'nullable|image|max:5120',
            'project_file' => 'nullable|file|mimes:pdf,ppt,pptx,doc,docx|max:10240',
            'display_priority' => 'nullable|integer',
            'is_active' => 'boolean',
            'starts_at' => 'nullable|date',
            'ends_at' => 'nullable|date|after_or_equal:starts_at',
        ]);

        $thumbnailUrl = $recommendedProject->thumbnail_url;
        if ($request->hasFile('thumbnail')) {
            $upload = $this->fileUploadService->upload($request->file('thumbnail'), 'gallery');
            $thumbnailUrl = $upload['url'];
        }

        $projectFileUrl = $recommendedProject->project_file_url;
        if ($request->hasFile('project_file')) {
            $upload = $this->fileUploadService->upload($request->file('project_file'), 'materials');
            $projectFileUrl = $upload['url'];

            // Fallback: Generate thumbnail preview from document if thumbnail is missing entirely
            if (!$thumbnailUrl) {
                $previewFile = $this->previewService->generatePreview($request->file('project_file'));
                if ($previewFile) {
                    $previewUpload = $this->fileUploadService->upload($previewFile, 'gallery');
                    $thumbnailUrl = $previewUpload['url'];
                    @unlink($previewFile->getRealPath()); // Clean up temp file
                }
            }
        }

        $recommendedProject->update([
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'ratio' => $validated['ratio'],
            'project_type' => $validated['project_type'] ?? null,
            'tags' => !empty($validated['tags']) ? array_map('trim', explode(',', $validated['tags'])) : null,
            'modules' => !empty($validated['modules']) ? array_map('trim', explode(',', $validated['modules'])) : null,
            'thumbnail_url' => $thumbnailUrl,
            'project_file_url' => $projectFileUrl,
            'display_priority' => $validated['display_priority'] ?? 0,
            'is_active' => $request->has('is_active'),
            'starts_at' => $validated['starts_at'] ?? null,
            'ends_at' => $validated['ends_at'] ?? null,
            'updated_by' => auth()->id(),
        ]);

        ActivityLog::create([
            'actor_id' => auth()->id(),
            'action' => 'update_recommended_project',
            'subject_type' => RecommendedProject::class,
            'subject_id' => $recommendedProject->id,
            'metadata' => ['title' => $recommendedProject->title],
        ]);

        return back()->with('success', 'Recommended Project updated successfully.');
    }

    public function destroy(RecommendedProject $recommendedProject)
    {
        $title = $recommendedProject->title;
        $recommendedProject->delete();

        ActivityLog::create([
            'actor_id' => auth()->id(),
            'action' => 'delete_recommended_project',
            'subject_type' => RecommendedProject::class,
            'subject_id' => $recommendedProject->id,
            'metadata' => ['title' => $title],
        ]);

        return back()->with('success', 'Recommended Project deleted successfully.');
    }
    
    public function toggleActive(RecommendedProject $recommendedProject)
    {
        $recommendedProject->update(['is_active' => !$recommendedProject->is_active]);

        ActivityLog::create([
            'actor_id' => auth()->id(),
            'action' => 'toggle_active_recommended_project',
            'subject_type' => RecommendedProject::class,
            'subject_id' => $recommendedProject->id,
            'metadata' => ['is_active' => $recommendedProject->is_active],
        ]);

        return back()->with('success', 'Project status toggled successfully.');
    }
}
