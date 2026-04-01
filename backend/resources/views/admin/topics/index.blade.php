@extends('admin.layouts.app')

@section('title', 'Manajemen Topik')
@section('page-title', 'Topics')
@section('page-description', 'Kelola struktur hierarki topik di aplikasi.')

@section('content')
<div class="space-y-6">

    {{-- Filter & Search --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-4">
        <form method="GET" action="{{ route('admin.topics.index') }}" class="flex items-center gap-4">
            <div class="flex-1 relative">
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari judul topik..." class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
            </div>
            <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                Cari
            </button>
            @if(request()->filled('search'))
                <a href="{{ route('admin.topics.index') }}" class="text-slate-400 hover:text-slate-200 text-sm">Reset</a>
            @endif
        </form>
    </div>

    {{-- Table --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-slate-400">
                <thead class="text-xs uppercase bg-slate-800 text-slate-400 border-b border-slate-700">
                    <tr>
                        <th scope="col" class="px-6 py-4 w-16">No</th>
                        <th scope="col" class="px-6 py-4">Judul Topik</th>
                        <th scope="col" class="px-6 py-4 text-center">Order</th>
                        <th scope="col" class="px-6 py-4 text-center">Status</th>
                        <th scope="col" class="px-6 py-4 text-right">Aksi</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-800">
                    @forelse($topics as $index => $topic)
                    <tr class="hover:bg-slate-800/50 transition">
                        <td class="px-6 py-4">{{ $topics->firstItem() + $index }}</td>
                        <td class="px-6 py-4">
                            <div class="font-medium text-slate-200">{{ $topic->title }}</div>
                            <div class="text-xs text-slate-500">Dibuat {{ $topic->created_at->format('d M Y') }}</div>
                        </td>
                        <td class="px-6 py-4 text-center">
                            <div class="flex items-center justify-center gap-2">
                                <form action="{{ route('admin.topics.reorder', $topic->id) }}" method="POST">
                                    @csrf @method('PATCH')
                                    <input type="hidden" name="direction" value="up">
                                    <button type="submit" class="p-1 text-slate-400 hover:text-indigo-400" {{ $loop->first && $topics->onFirstPage() ? 'disabled' : '' }}>
                                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M12 19.5v-15m0 0l-6.75 6.75M12 4.5l6.75 6.75" /></svg>
                                    </button>
                                </form>
                                <span class="text-slate-200 w-4 text-center">{{ $topic->order }}</span>
                                <form action="{{ route('admin.topics.reorder', $topic->id) }}" method="POST">
                                    @csrf @method('PATCH')
                                    <input type="hidden" name="direction" value="down">
                                    <button type="submit" class="p-1 text-slate-400 hover:text-indigo-400" {{ $loop->last && $topics->onLastPage() ? 'disabled' : '' }}>
                                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 13.5L12 21m0 0l-7.5-7.5M12 21V3" /></svg>
                                    </button>
                                </form>
                            </div>
                        </td>
                        <td class="px-6 py-4 text-center">
                            <form action="{{ route('admin.topics.toggle-publish', $topic->id) }}" method="POST">
                                @csrf @method('PATCH')
                                <button type="submit" class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {{ $topic->is_published ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-400 border border-slate-700' }}">
                                    {{ $topic->is_published ? 'Published' : 'Draft' }}
                                </button>
                            </form>
                        </td>
                        <td class="px-6 py-4 flex justify-end gap-3">
                            <a href="{{ route('admin.topics.edit', $topic->id) }}" class="text-indigo-400 hover:text-indigo-300 text-sm font-medium">Edit</a>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="5">
                            @include('admin.partials.empty-state', [
                                'title'   => 'Topik tidak ditemukan',
                                'message' => 'Belum ada topik yang dibuat atau sesuai dengan pencarian.',
                            ])
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        {{-- Pagination --}}
        @if($topics->hasPages())
        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900">
            {{ $topics->links() }}
        </div>
        @endif
    </div>
</div>
@endsection
