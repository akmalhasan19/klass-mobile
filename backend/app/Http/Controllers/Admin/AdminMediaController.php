<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\MediaFile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class AdminMediaController extends Controller
{
    public function index(Request $request): View
    {
        $category = $request->query('category');
        $search = $request->query('search');

        $medias = MediaFile::query()
            ->with('uploader')
            ->when($category, fn($q) => $q->where('category', $category))
            ->when($search, fn($q) => $q->where('file_name', 'like', "%{$search}%"))
            ->latest()
            ->paginate(16)
            ->withQueryString();

        // Get unique categories for filter
        $categories = MediaFile::select('category')->distinct()->pluck('category');

        return view('admin.media.index', compact('medias', 'category', 'search', 'categories'));
    }

    public function destroy(MediaFile $media)
    {
        $disk = $media->disk ?? 'public';
        $path = $media->file_path;
        $id = $media->id;

        // Perform physical deletion if it exists
        if (Storage::disk($disk)->exists($path)) {
            Storage::disk($disk)->delete($path);
        }

        // DB record deletion
        $media->delete();

        ActivityLog::create([
            'actor_id'     => auth()->id(),
            'action'       => 'delete_media',
            'subject_type' => MediaFile::class,
            'subject_id'   => $id,
            'metadata'     => [
                'disk' => $disk,
                'path' => $path,
            ],
        ]);

        return back()->with('success', 'Media berhasil dihapus dari sistem storage dan database.');
    }
}
