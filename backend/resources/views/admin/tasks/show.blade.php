@extends('admin.layouts.app')

@section('title', 'Tinjauan Task')
@section('page-title', 'Detail & Cek Task')
@section('page-description', 'Tinjau metadata task dan berikan moderasi apabila bermasalah.')

@section('content')
<div class="space-y-6">

    <div class="flex items-center justify-between">
        <a href="{{ route('admin.tasks.index') }}" class="inline-flex items-center text-sm font-medium text-slate-400 hover:text-white transition">
            <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
            </svg>
            Kembali ke Daftar Tasks
        </a>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {{-- Info Card --}}
        <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden p-6 space-y-4">
            <h3 class="text-lg font-semibold text-slate-200 border-b border-slate-800 pb-2">Data Marketplace Task</h3>

            <div>
                <span class="block text-xs font-semibold text-slate-500 uppercase tracking-widest mb-1">ID Tugas</span>
                <p class="text-sm font-mono text-slate-300 break-all">{{ $task->id }}</p>
            </div>

            <div>
                <span class="block text-xs font-semibold text-slate-500 uppercase tracking-widest mb-1">Konten Pemilik (Parent)</span>
                @if($task->content)
                <p class="text-sm text-slate-300 font-medium">{{ $task->content->title }}</p>
                <p class="text-xs text-slate-500 mt-0.5">Berada di Topik: {{ $task->content->topic?->title ?? '-' }}</p>
                @else
                <p class="text-sm text-red-400 italic">Konten induk telah dihapus oleh User / Admin sebelumnya.</p>
                @endif
            </div>

            <div>
                <span class="block text-xs font-semibold text-slate-500 uppercase tracking-widest mb-1">Waktu Dibuat</span>
                <p class="text-sm text-slate-300">{{ $task->created_at->format('d F Y, H:i') }}</p>
            </div>

            @if($task->attachment_url)
            <div>
                <span class="block text-xs font-semibold text-slate-500 uppercase tracking-widest mb-1">Attachment Upload</span>
                <a href="{{ $task->attachment_url }}" target="_blank" class="inline-flex items-center gap-2 text-sm text-blue-400 hover:text-blue-300 hover:underline">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244" /></svg>
                    Buka File Lampiran
                </a>
            </div>
            @endif
        </div>

        {{-- Administration Actions --}}
        <div class="space-y-6">
            
            {{-- Update Status --}}
            <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden p-6">
                <h3 class="text-sm font-medium text-slate-200 mb-4">Ubah Status Paksa (Admin Override)</h3>
                
                <form action="{{ route('admin.tasks.update-status', $task->id) }}" method="POST" class="flex gap-4 items-end">
                    @csrf
                    @method('PATCH')
                    
                    <div class="flex-1">
                        <label for="status" class="block text-xs text-slate-400 mb-1">Status Baru</label>
                        <select name="status" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
                            <option value="open" {{ $task->status == 'open' ? 'selected' : '' }}>Open</option>
                            <option value="taken" {{ $task->status == 'taken' ? 'selected' : '' }}>Taken</option>
                            <option value="in_progress" {{ $task->status == 'in_progress' ? 'selected' : '' }}>In Progress</option>
                            <option value="completed" {{ $task->status == 'completed' ? 'selected' : '' }}>Completed</option>
                            <option value="verified" {{ $task->status == 'verified' ? 'selected' : '' }}>Verified</option>
                        </select>
                    </div>

                    <button type="submit" class="bg-amber-600 hover:bg-amber-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition shrink-0">
                        Update Status
                    </button>
                </form>
            </div>

            {{-- Delete Moderation --}}
            <div class="bg-slate-900 border border-red-900/50 rounded-xl overflow-hidden p-6">
                <h3 class="text-sm font-medium text-red-400 mb-2">Hapus Berkas (Moderasi Sepihak)</h3>
                <p class="text-xs text-slate-400 mb-4">Gunakan aksi ini jika Task dilaporkan melanggar S&K aplikasi, mengandung eksploitasi, atau tidak wajar. Transaksi tidak akan dapat diselamatkan jika ia sedang berjalan di sisi user.</p>

                <form action="{{ route('admin.tasks.destroy', $task->id) }}" method="POST" onsubmit="return confirm('Peringatan: Anda akan menghapus task ini secara permanen. Pengguna tidak akan dapat mengaksesnya kembali. Yakin ingin melanjutkan?');">
                    @csrf
                    @method('DELETE')
                    <button type="submit" class="bg-red-500/10 hover:bg-red-500/20 text-red-500 border border-red-500/50 font-medium rounded-lg text-sm px-5 py-2 transition w-full">
                        Hapus Permanen Task Ini
                    </button>
                </form>
            </div>

        </div>

    </div>
</div>
@endsection
