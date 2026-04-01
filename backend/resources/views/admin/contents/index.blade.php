@extends('admin.layouts.app')

@section('title', 'Manajemen Konten')
@section('page-title', 'Contents')
@section('page-description', 'Kelola materi/konten pembelajaran aplikasi.')

@section('content')
<div class="space-y-6">

    {{-- Filter & Search --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-4">
        <form method="GET" action="{{ route('admin.contents.index') }}" class="flex flex-col md:flex-row gap-4">
            
            <div class="flex-1">
                <select name="topic_id" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
                    <option value="">Semua Topik</option>
                    @foreach($topics as $topic)
                        <option value="{{ $topic->id }}" {{ $topicId == $topic->id ? 'selected' : '' }}>
                            {{ $topic->title }} (Order: {{ $topic->order }})
                        </option>
                    @endforeach
                </select>
            </div>

            <div class="flex-1 relative">
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari judul konten..." class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
            </div>

            <div class="flex gap-2">
                <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                    Filter
                </button>
                @if(request()->filled('search') || request()->filled('topic_id'))
                    <a href="{{ route('admin.contents.index') }}" class="bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium rounded-lg text-sm px-5 py-2.5 transition">Reset</a>
                @endif
            </div>
        </form>
    </div>

    {{-- Info Reorder --}}
    @if($topicId)
    <div class="bg-blue-500/10 border border-blue-500/20 text-blue-300 text-sm p-4 rounded-xl flex items-start gap-3">
        <svg class="w-5 h-5 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
        </svg>
        <p>Anda memfilter berdasarkan topik spesifik. Panah reorder di bawah ini akan memindahkan urutan konten di dalam topik <strong>{{ $topics->firstWhere('id', $topicId)->title ?? 'ini' }}</strong>.</p>
    </div>
    @endif

    {{-- Table --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-slate-400">
                <thead class="text-xs uppercase bg-slate-800 text-slate-400 border-b border-slate-700">
                    <tr>
                        <th scope="col" class="px-6 py-4 w-16">No</th>
                        <th scope="col" class="px-6 py-4">Konten & Topik</th>
                        <th scope="col" class="px-6 py-4 text-center">Order</th>
                        <th scope="col" class="px-6 py-4 text-center">Status</th>
                        <th scope="col" class="px-6 py-4 text-right">Aksi</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-800">
                    @forelse($contents as $index => $content)
                    <tr class="hover:bg-slate-800/50 transition">
                        <td class="px-6 py-4">{{ $contents->firstItem() + $index }}</td>
                        <td class="px-6 py-4">
                            <div class="font-medium text-slate-200">{{ $content->title }}</div>
                            <div class="text-xs text-slate-500">Topik: {{ $content->topic?->title ?? '-' }}</div>
                        </td>
                        <td class="px-6 py-4 text-center">
                            @if($topicId)
                            <div class="flex items-center justify-center gap-2">
                                <form action="{{ route('admin.contents.reorder', $content->id) }}" method="POST">
                                    @csrf @method('PATCH')
                                    <input type="hidden" name="direction" value="up">
                                    <button type="submit" class="p-1 text-slate-400 hover:text-indigo-400" {{ $loop->first && $contents->onFirstPage() ? 'disabled' : '' }}>
                                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M12 19.5v-15m0 0l-6.75 6.75M12 4.5l6.75 6.75" /></svg>
                                    </button>
                                </form>
                                <span class="text-slate-200 w-4 text-center">{{ $content->order }}</span>
                                <form action="{{ route('admin.contents.reorder', $content->id) }}" method="POST">
                                    @csrf @method('PATCH')
                                    <input type="hidden" name="direction" value="down">
                                    <button type="submit" class="p-1 text-slate-400 hover:text-indigo-400" {{ $loop->last && $contents->onLastPage() ? 'disabled' : '' }}>
                                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 13.5L12 21m0 0l-7.5-7.5M12 21V3" /></svg>
                                    </button>
                                </form>
                            </div>
                            @else
                            <span class="text-slate-500" title="Pilih spesifik topik terlebih dahulu untuk reorder">#{{ $content->order }}</span>
                            @endif
                        </td>
                        <td class="px-6 py-4 text-center">
                            <form action="{{ route('admin.contents.toggle-publish', $content->id) }}" method="POST">
                                @csrf @method('PATCH')
                                <button type="submit" class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {{ $content->is_published ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-400 border border-slate-700' }}">
                                    {{ $content->is_published ? 'Published' : 'Draft' }}
                                </button>
                            </form>
                        </td>
                        <td class="px-6 py-4 flex justify-end gap-3">
                            <a href="{{ route('admin.contents.edit', $content->id) }}" class="text-indigo-400 hover:text-indigo-300 text-sm font-medium">Edit</a>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="5">
                            @include('admin.partials.empty-state', [
                                'title'   => 'Konten tidak ditemukan',
                                'message' => 'Belum ada konten yang dibuat atau sesuai dengan pencarian/filter.',
                            ])
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        {{-- Pagination --}}
        @if($contents->hasPages())
        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900">
            {{ $contents->links() }}
        </div>
        @endif
    </div>
</div>
@endsection
