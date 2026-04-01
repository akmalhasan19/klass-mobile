@extends('admin.layouts.app')

@section('title', 'Marketplace Tasks')
@section('page-title', 'Tasks Moderation')
@section('page-description', 'Kelola, awasi status, dan moderasi tugas marketplace.')

@section('content')
<div class="space-y-6">

    {{-- Filter & Search --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-4">
        <form method="GET" action="{{ route('admin.tasks.index') }}" class="flex flex-col md:flex-row gap-4">
            
            <div class="flex-1 max-w-xs">
                <select name="status" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
                    <option value="">Semua Status</option>
                    <option value="open" {{ $status == 'open' ? 'selected' : '' }}>Open</option>
                    <option value="taken" {{ $status == 'taken' ? 'selected' : '' }}>Taken (Diambil)</option>
                    <option value="in_progress" {{ $status == 'in_progress' ? 'selected' : '' }}>In Progress</option>
                    <option value="completed" {{ $status == 'completed' ? 'selected' : '' }}>Completed</option>
                    <option value="verified" {{ $status == 'verified' ? 'selected' : '' }}>Verified / Closed</option>
                </select>
            </div>

            <div class="flex-1 relative">
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari berdasarkan judul konten terkait..." class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
            </div>

            <div class="flex gap-2">
                <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                    Filter
                </button>
                @if(request()->filled('search') || request()->filled('status'))
                    <a href="{{ route('admin.tasks.index') }}" class="bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium rounded-lg text-sm px-5 py-2.5 transition">Reset</a>
                @endif
            </div>
        </form>
    </div>

    {{-- Table --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-slate-400">
                <thead class="text-xs uppercase bg-slate-800 text-slate-400 border-b border-slate-700">
                    <tr>
                        <th scope="col" class="px-6 py-4">Konten (Task Parent)</th>
                        <th scope="col" class="px-6 py-4">Dibuat Pada</th>
                        <th scope="col" class="px-6 py-4 text-center">Status</th>
                        <th scope="col" class="px-6 py-4 text-right">Aksi</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-800">
                    @forelse($tasks as $task)
                    <tr class="hover:bg-slate-800/50 transition">
                        <td class="px-6 py-4">
                            @if($task->content)
                            <div class="font-medium text-slate-200 max-w-sm truncate" title="{{ $task->content->title }}">{{ $task->content->title }}</div>
                            <div class="text-xs text-slate-500">Topik: {{ $task->content->topic?->title ?? '-' }}</div>
                            @else
                            <div class="font-medium text-red-400">Konten Induk Hilang (Orphaned)</div>
                            @endif
                        </td>
                        <td class="px-6 py-4 text-slate-400 whitespace-nowrap">
                            {{ $task->created_at->format('d M Y H:i') }}
                        </td>
                        <td class="px-6 py-4 text-center">
                            @php
                                $badgeClass = match($task->status) {
                                    'open' => 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
                                    'taken', 'in_progress' => 'bg-blue-500/10 text-blue-400 border-blue-500/20',
                                    'completed', 'verified' => 'bg-slate-700 text-slate-300 border-slate-600',
                                    default => 'bg-slate-800 text-slate-400 border-slate-700',
                                };
                            @endphp
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border {{ $badgeClass }}">
                                {{ strtoupper($task->status ?? 'UNKNOWN') }}
                            </span>
                        </td>
                        <td class="px-6 py-4 flex justify-end gap-3">
                            <a href="{{ route('admin.tasks.show', $task->id) }}" class="text-indigo-400 hover:text-indigo-300 text-sm font-medium">Tinjau / Moderate</a>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="4">
                            @include('admin.partials.empty-state', [
                                'title'   => 'Task tidak ditemukan',
                                'message' => 'Belum ada task yang diposting atau kriteria pencarian tidak cocok.',
                            ])
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        {{-- Pagination --}}
        @if($tasks->hasPages())
        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900">
            {{ $tasks->links() }}
        </div>
        @endif
    </div>
</div>
@endsection
