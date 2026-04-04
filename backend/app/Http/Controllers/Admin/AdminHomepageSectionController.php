<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminHomepageSectionController extends Controller
{
    /**
     * Tampilkan konfigurasi homepage sections.
     */
    public function index(Request $request): View
    {
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

        return view('admin.homepage-sections.index', compact('recommendedProjects'));
    }
}
