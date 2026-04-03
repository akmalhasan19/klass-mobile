<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\HomepageSection;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminHomepageSectionController extends Controller
{
    /**
     * Tampilkan konfigurasi homepage sections.
     */
    public function index(Request $request): View
    {
        $sections = HomepageSection::orderBy('position', 'asc')->get();
        
        $query = \App\Models\RecommendedProject::query();
        
        if ($request->filled('source_type')) {
            $query->where('source_type', $request->source_type);
        }
        
        if ($request->filled('status')) {
            $now = now();
            switch ($request->status) {
                case 'active':
                    $query->where('is_active', true)
                          ->where(function($q) use ($now) {
                              $q->whereNull('starts_at')->orWhere('starts_at', '<=', $now);
                          })
                          ->where(function($q) use ($now) {
                              $q->whereNull('ends_at')->orWhere('ends_at', '>=', $now);
                          });
                    break;
                case 'inactive':
                    $query->where('is_active', false);
                    break;
                case 'scheduled':
                    $query->where('is_active', true)->where('starts_at', '>', $now);
                    break;
                case 'expired':
                    $query->where('is_active', true)->where('ends_at', '<', $now);
                    break;
            }
        }
        
        $recommendedProjects = $query->orderBy('display_priority', 'desc')->get();

        return view('admin.homepage-sections.index', compact('sections', 'recommendedProjects'));
    }

    /**
     * Update order dan label.
     */
    public function update(Request $request)
    {
        $validated = $request->validate([
            'sections' => 'required|array',
            'sections.*.id' => 'required|exists:homepage_sections,id',
            'sections.*.label' => 'required|string|max:100',
            'sections.*.position' => 'required|integer',
            'sections.*.is_enabled' => 'boolean',
        ]);

        $oldSections = HomepageSection::orderBy('position')->get()->keyBy('id');

        foreach ($validated['sections'] as $sectionData) {
            $section = HomepageSection::find($sectionData['id']);
            $isEnabled = isset($sectionData['is_enabled']) ? true : false;
            
            $section->update([
                'label'      => $sectionData['label'],
                'position'   => $sectionData['position'],
                'is_enabled' => $isEnabled,
            ]);
        }

        ActivityLog::create([
            'actor_id'     => auth()->id(),
            'action'       => 'update_homepage_sections',
            'subject_type' => HomepageSection::class,
            'subject_id'   => 'bulk',
            'metadata'     => [
                'updated_count' => count($validated['sections']),
            ],
        ]);

        return back()->with('success', 'Konfigurasi homepage section berhasil diperbarui.');
    }
}
