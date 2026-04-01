@extends('admin.layouts.app')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard')
@section('page-description', 'Ringkasan operasional aplikasi Klass')

@section('content')
<div class="space-y-6">

    {{-- Filter Waktu --}}
    <div class="flex justify-end">
        <form method="GET" action="{{ route('admin.dashboard') }}" class="flex items-center space-x-2">
            <label for="period" class="text-sm text-slate-400">Filter Waktu:</label>
            <select name="period" id="period" onchange="this.form.submit()" class="bg-slate-900 border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block p-2">
                <option value="all" {{ $period === 'all' ? 'selected' : '' }}>Semua Waktu</option>
                <option value="today" {{ $period === 'today' ? 'selected' : '' }}>Hari Ini</option>
                <option value="7_days" {{ $period === '7_days' ? 'selected' : '' }}>7 Hari Terakhir</option>
                <option value="30_days" {{ $period === '30_days' ? 'selected' : '' }}>30 Hari Terakhir</option>
            </select>
        </form>
    </div>

    {{-- Welcome banner --}}
    <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-indigo-600 to-violet-700 p-6 shadow-lg shadow-indigo-500/20">
        <div class="relative z-10">
            <h2 class="text-lg font-semibold text-white">Selamat datang, {{ Auth::user()->name }}! 👋</h2>
            <p class="text-sm text-indigo-200 mt-1">
                Panel admin Klass siap digunakan. Berikut adalah data monitoring operasional sistem.
            </p>
        </div>
        {{-- Decorative circles --}}
        <div class="absolute -right-8 -top-8 w-40 h-40 rounded-full bg-white/5"></div>
        <div class="absolute -right-4 -bottom-12 w-56 h-56 rounded-full bg-white/5"></div>
    </div>

    {{-- Summary cards --}}
    <div class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        @foreach([
            ['label' => 'Total Users',      'value' => number_format($usersCount),    'color' => 'indigo'],
            ['label' => 'Total Topics',     'value' => number_format($topicsCount),   'color' => 'blue'],
            ['label' => 'Total Contents',   'value' => number_format($contentsCount), 'color' => 'violet'],
            ['label' => 'Marketplace Tasks','value' => number_format($tasksCount),    'color' => 'amber'],
            ['label' => 'Media Files',      'value' => number_format($mediaCount),    'color' => 'emerald'],
            ['label' => 'Activity Logs',    'value' => number_format($activityCount), 'color' => 'slate'],
        ] as $card)
        <div class="bg-slate-900 border border-slate-800 rounded-xl p-5">
            <p class="text-xs font-medium text-slate-500 uppercase tracking-wider mb-2">{{ $card['label'] }}</p>
            <p class="text-2xl font-bold text-slate-100">{{ $card['value'] }}</p>
        </div>
        @endforeach
    </div>

    {{-- Recent Items Grid --}}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">

        {{-- Recent Users --}}
        <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-800">
                <h3 class="text-sm font-semibold text-slate-200">User Baru</h3>
            </div>
            <div class="p-0">
                @if($recentUsers->isEmpty())
                    <div class="p-6 text-center text-sm text-slate-500">Tidak ada user baru di periode ini.</div>
                @else
                    <ul class="divide-y divide-slate-800">
                        @foreach($recentUsers as $user)
                        <li class="px-6 py-3 flex justify-between items-center text-sm">
                            <div>
                                <p class="text-slate-200 font-medium">{{ $user->name }}</p>
                                <p class="text-slate-500 text-xs">{{ $user->email }}</p>
                            </div>
                            <span class="text-slate-500 text-xs flex-shrink-0">{{ $user->created_at->diffForHumans() }}</span>
                        </li>
                        @endforeach
                    </ul>
                @endif
            </div>
        </div>

        {{-- Recent Contents --}}
        <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-800">
                <h3 class="text-sm font-semibold text-slate-200">Konten Baru</h3>
            </div>
            <div class="p-0">
                @if($recentContents->isEmpty())
                    <div class="p-6 text-center text-sm text-slate-500">Tidak ada konten baru di periode ini.</div>
                @else
                    <ul class="divide-y divide-slate-800">
                        @foreach($recentContents as $content)
                        <li class="px-6 py-3 flex justify-between items-center text-sm">
                            <div class="truncate mr-4">
                                <p class="text-slate-200 font-medium truncate">{{ $content->title }}</p>
                                <p class="text-slate-500 text-xs">Topik: {{ $content->topic?->title ?? '-' }}</p>
                            </div>
                            <span class="text-slate-500 text-xs flex-shrink-0">{{ $content->created_at->diffForHumans() }}</span>
                        </li>
                        @endforeach
                    </ul>
                @endif
            </div>
        </div>

        {{-- Recent Tasks --}}
        <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-800">
                <h3 class="text-sm font-semibold text-slate-200">Marketplace Tasks Baru</h3>
            </div>
            <div class="p-0">
                @if($recentTasks->isEmpty())
                    <div class="p-6 text-center text-sm text-slate-500">Tidak ada task baru di periode ini.</div>
                @else
                    <ul class="divide-y divide-slate-800">
                        @foreach($recentTasks as $task)
                        <li class="px-6 py-3 flex justify-between items-center text-sm">
                            <div class="truncate mr-4">
                                <p class="text-slate-200 font-medium truncate">{{ $task->content?->title ?? 'Deleted Content' }}</p>
                                <p class="text-slate-500 text-xs">Status: {{ ucfirst($task->status) }}</p>
                            </div>
                            <span class="text-slate-500 text-xs flex-shrink-0">{{ $task->created_at->diffForHumans() }}</span>
                        </li>
                        @endforeach
                    </ul>
                @endif
            </div>
        </div>

        {{-- Recent Media --}}
        <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-800">
                <h3 class="text-sm font-semibold text-slate-200">Media/File Baru</h3>
            </div>
            <div class="p-0">
                @if($recentMedia->isEmpty())
                    <div class="p-6 text-center text-sm text-slate-500">Tidak ada media baru di periode ini.</div>
                @else
                    <ul class="divide-y divide-slate-800">
                        @foreach($recentMedia as $media)
                        <li class="px-6 py-3 flex justify-between items-center text-sm">
                            <div class="truncate mr-4 flex items-center space-x-2">
                                <span class="bg-slate-800 px-2 py-0.5 rounded text-[10px] text-slate-400 uppercase">{{ $media->category }}</span>
                                <p class="text-slate-200 font-medium truncate">{{ $media->file_name }}</p>
                            </div>
                            <span class="text-slate-500 text-xs flex-shrink-0">{{ $media->created_at->diffForHumans() }}</span>
                        </li>
                        @endforeach
                    </ul>
                @endif
            </div>
        </div>

    </div>

    {{-- Recent Activity Log --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div class="px-6 py-4 border-b border-slate-800">
            <h3 class="text-sm font-semibold text-slate-200">Aktivitas Sistem / Audit Log Terbaru</h3>
        </div>
        <div class="p-0">
            @if($recentActivity->isEmpty())
                <div class="p-6 text-center text-sm text-slate-500">Belum ada activity log yang tercatat.</div>
            @else
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm text-slate-400">
                        <thead class="text-xs uppercase bg-slate-800 text-slate-400">
                            <tr>
                                <th scope="col" class="px-6 py-3">Waktu</th>
                                <th scope="col" class="px-6 py-3">Aktor</th>
                                <th scope="col" class="px-6 py-3">Aksi</th>
                                <th scope="col" class="px-6 py-3">Subject</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-800">
                            @foreach($recentActivity as $log)
                            <tr class="hover:bg-slate-800/50">
                                <td class="px-6 py-3 whitespace-nowrap">{{ $log->created_at->format('d M Y H:i') }}</td>
                                <td class="px-6 py-3 font-medium text-slate-300">{{ $log->actor?->name ?? 'System' }}</td>
                                <td class="px-6 py-3">
                                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-800 text-slate-300">
                                        {{ $log->action }}
                                    </span>
                                </td>
                                <td class="px-6 py-3">
                                    <p class="text-slate-300 truncate max-w-xs">{{ class_basename($log->subject_type) }} #{{ substr($log->subject_id, 0, 8) }}...</p>
                                </td>
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </div>
    </div>

</div>
@endsection
