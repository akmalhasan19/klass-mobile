@extends('admin.layouts.app')

@section('title', 'Activity Logs')
@section('page-title', 'Activity Logs')
@section('page-description', 'Pantau aktivitas penting yang dilakukan oleh admin atau sistem.')

@section('content')
<div class="space-y-6">

    {{-- Filter & Search --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-4">
        <form method="GET" action="{{ route('admin.activity-logs.index') }}" class="flex flex-wrap items-center gap-4">
            
            <div class="flex-1 min-w-[150px]">
                <select name="action" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 w-full p-2.5">
                    <option value="">-- Semua Action --</option>
                    @foreach($actions as $act)
                        <option value="{{ $act }}" @selected(request('action') == $act)>{{ $act }}</option>
                    @endforeach
                </select>
            </div>

            <div class="flex-1 min-w-[150px]">
                <select name="actor_id" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 w-full p-2.5">
                    <option value="">-- Semua Actor --</option>
                    @foreach($actors as $actor)
                        <option value="{{ $actor->id }}" @selected(request('actor_id') == $actor->id)>{{ $actor->name }}</option>
                    @endforeach
                </select>
            </div>

            <div class="flex-1 min-w-[150px]">
                <select name="subject_type" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 w-full p-2.5">
                    <option value="">-- Semua Entity --</option>
                    @foreach($entityTypes as $type)
                        <option value="{{ $type }}" @selected(request('subject_type') == $type)>{{ class_basename($type) }}</option>
                    @endforeach
                </select>
            </div>
            
            <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                Filter
            </button>
            
            @if(request()->anyFilled(['action', 'actor_id', 'subject_type', 'date_from', 'date_to']))
                <a href="{{ route('admin.activity-logs.index') }}" class="text-slate-400 hover:text-slate-200 text-sm ml-2">Reset</a>
            @endif
        </form>
    </div>

    {{-- Table --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-slate-400">
                <thead class="text-xs uppercase bg-slate-800 text-slate-400 border-b border-slate-700">
                    <tr>
                        <th scope="col" class="px-6 py-4">Waktu</th>
                        <th scope="col" class="px-6 py-4">Actor</th>
                        <th scope="col" class="px-6 py-4">Action</th>
                        <th scope="col" class="px-6 py-4">Entity</th>
                        <th scope="col" class="px-6 py-4">Metadata</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-800">
                    @forelse($logs as $log)
                    <tr class="hover:bg-slate-800/50 transition whitespace-nowrap">
                        <td class="px-6 py-4 text-slate-300">
                            {{ $log->created_at->format('d M Y H:i:s') }}
                        </td>
                        <td class="px-6 py-4">
                            @if($log->actor)
                                <div class="font-medium text-slate-200">{{ $log->actor->name }}</div>
                                <div class="text-xs text-slate-500">{{ $log->actor->email }}</div>
                            @else
                                <span class="text-slate-500 italic">System / Deleted User</span>
                            @endif
                        </td>
                        <td class="px-6 py-4">
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-800 text-slate-300 border border-slate-700">
                                {{ $log->action }}
                            </span>
                        </td>
                        <td class="px-6 py-4">
                            <div class="text-slate-300">{{ class_basename($log->subject_type) }}</div>
                            <div class="text-xs text-slate-500" title="{{ $log->subject_id }}">{{ Str::limit($log->subject_id, 13) }}</div>
                        </td>
                        <td class="px-6 py-4">
                            <button onclick="alert(JSON.stringify({{ json_encode($log->metadata) }}, null, 2))" class="text-indigo-400 hover:text-indigo-300 text-sm font-medium">
                                Lihat
                            </button>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="5">
                            @include('admin.partials.empty-state', [
                                'title'   => 'Tidak ada log',
                                'message' => 'Belum ada activity log yang sesuai dengan filter Anda.',
                            ])
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        {{-- Pagination --}}
        @if($logs->hasPages())
        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900">
            {{ $logs->links() }}
        </div>
        @endif
    </div>
</div>
@endsection
