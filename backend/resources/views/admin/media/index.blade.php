@extends('admin.layouts.app')

@section('title', 'Media Management')
@section('page-title', 'File / Media Storage')
@section('page-description', 'Manajemen file terpusat seperti avatar, lampiran task, dan konten galeri.')

@section('content')
<div class="space-y-6">

    {{-- Filter & Search --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-4">
        <form method="GET" action="{{ route('admin.media.index') }}" class="flex flex-col md:flex-row gap-4">
            
            <div class="flex-1 max-w-xs">
                <select name="category" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
                    <option value="">Semua Kategori</option>
                    @foreach($categories as $cat)
                        <option value="{{ $cat }}" {{ $category == $cat ? 'selected' : '' }}>{{ strtoupper($cat) }}</option>
                    @endforeach
                </select>
            </div>

            <div class="flex-1 relative">
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari nama file..." class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
            </div>

            <div class="flex gap-2">
                <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                    Cari File
                </button>
                @if(request()->filled('search') || request()->filled('category'))
                    <a href="{{ route('admin.media.index') }}" class="bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium rounded-lg text-sm px-5 py-2.5 transition">Reset</a>
                @endif
            </div>
        </form>
    </div>

    {{-- Info --}}
    <div class="bg-amber-500/10 border border-amber-500/20 text-amber-300 text-sm p-4 rounded-xl flex items-start gap-3">
        <svg class="w-5 h-5 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <p><strong>Peringatan Hapus:</strong> Tindakan menghapus file dari manajemen media bermaksud mencabut (revoke) fisik obyek di Bucket Storage. Aksi ini tidak bisa *di-undo*, dan Anda mungkin saja akan merusak tampilan aplikasi user jika file tersebut digunakan pada materi live.</p>
    </div>

    {{-- Grid View --}}
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
        @forelse($medias as $media)
            @php
                // Check if image for preview
                $isImage = str_contains($media->mime_type, 'image/');
                // File Size Formatting
                $size = str_replace(' bytes', '', formatBytes($media->size ?? 0));
                
                function formatBytes($bytes, $precision = 2) { 
                    $units = array('B', 'KB', 'MB', 'GB', 'TB'); 
                    $bytes = max($bytes, 0); 
                    $pow = floor(($bytes ? log($bytes) : 0) / log(1024)); 
                    $pow = min($pow, count($units) - 1); 
                    $bytes /= pow(1024, $pow);
                    return round($bytes, $precision) . ' ' . $units[$pow]; 
                }
            @endphp
        <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden flex flex-col group relative">
            
            {{-- Preview Box --}}
            <div class="h-32 bg-slate-950/50 flex items-center justify-center p-2 relative overflow-hidden group">
                @if($isImage)
                    <img src="{{ Storage::disk($media->disk ?? 'public')->url($media->file_path) }}" alt="{{ $media->file_name }}" class="object-cover w-full h-full opacity-80 group-hover:opacity-100 transition duration-300 group-hover:scale-105">
                @else
                    <svg class="w-10 h-10 text-slate-700" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m3.75 9v6m3-3H9m1.5-12H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                    </svg>
                @endif
                
                {{-- Category Badge Overlay --}}
                <span class="absolute top-2 left-2 px-1.5 py-0.5 rounded text-[9px] uppercase tracking-wider font-bold bg-black/60 text-white shadow-sm ring-1 ring-white/10 backdrop-blur-sm">
                    {{ $media->category }}
                </span>
            </div>

            {{-- Info Box --}}
            <div class="p-3 flex-1 flex flex-col justify-between">
                <div>
                    <h4 class="text-xs font-semibold text-slate-200 truncate" title="{{ $media->file_name }}">{{ $media->file_name }}</h4>
                    <p class="text-[10px] text-slate-500 mt-1 uppercase">{{ $size }} • {{ explode('/', $media->mime_type)[1] ?? 'FILE' }}</p>
                </div>

                <div class="mt-3 pt-3 border-t border-slate-800 flex justify-between items-center">
                    <a href="{{ Storage::disk($media->disk ?? 'public')->url($media->file_path) }}" target="_blank" class="text-xs font-medium text-indigo-400 hover:text-indigo-300">
                        Lihat URL
                    </a>
                    <form action="{{ route('admin.media.destroy', $media->id) }}" method="POST" onsubmit="return confirm('Apakah Anda yakin ingin menghapus file ini dari Storage Sistem? Langkah ini tidak bisa diundo!');">
                        @csrf
                        @method('DELETE')
                        <button type="submit" class="text-slate-500 hover:text-red-400">
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                            </svg>
                        </button>
                    </form>
                </div>
            </div>
        </div>
        @empty
        <div class="col-span-full">
            @include('admin.partials.empty-state', [
                'title'   => 'Media Kosong',
                'message' => 'Sistem tidak mendeteksi record media pada klasifikasi yang diberikan.',
            ])
        </div>
        @endforelse
    </div>

    {{-- Pagination --}}
    @if($medias->hasPages())
    <div class="mt-6 flex justify-center">
        {{ $medias->links() }}
    </div>
    @endif
</div>
@endsection
