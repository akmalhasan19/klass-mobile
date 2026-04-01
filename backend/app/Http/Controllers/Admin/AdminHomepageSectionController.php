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
    public function index(): View
    {
        $sections = HomepageSection::orderBy('position', 'asc')->get();

        return view('admin.homepage-sections.index', compact('sections'));
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
