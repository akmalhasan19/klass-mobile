@extends('admin.layouts.app')

@section('title', 'Manage Users')
@section('page-title', 'User Management')
@section('page-description', 'Cari pengguna dan kelola hak akses sistem.')

@section('content')
<div class="space-y-6">

    {{-- Filter & Search --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-4">
        <form method="GET" action="{{ route('admin.users.index') }}" class="flex items-center gap-4">
            <div class="flex-1 relative">
                <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none text-slate-500">
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                    </svg>
                </div>
                <input type="text" name="search" value="{{ $search }}" placeholder="Cari nama atau email pengguna..." class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full pl-10 p-2.5">
            </div>
            <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                Cari
            </button>
            @if(request()->filled('search'))
                <a href="{{ route('admin.users.index') }}" class="text-slate-400 hover:text-slate-200 text-sm">Reset</a>
            @endif
        </form>
    </div>

    {{-- Table --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-slate-400">
                <thead class="text-xs uppercase bg-slate-800 text-slate-400 border-b border-slate-700">
                    <tr>
                        <th scope="col" class="px-6 py-4">Pengguna</th>
                        <th scope="col" class="px-6 py-4">Role</th>
                        <th scope="col" class="px-6 py-4">Terdaftar Pada</th>
                        <th scope="col" class="px-6 py-4 text-right">Aksi</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-800">
                    @forelse($users as $user)
                    <tr class="hover:bg-slate-800/50 transition">
                        <td class="px-6 py-4">
                            <div class="font-medium text-slate-200">{{ $user->name }}</div>
                            <div class="text-xs text-slate-500">{{ $user->email }}</div>
                        </td>
                        <td class="px-6 py-4">
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {{ $user->isAdmin() ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20' : 'bg-slate-800 text-slate-300' }}">
                                {{ strtoupper($user->role) }}
                            </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-slate-400">
                            {{ $user->created_at->format('d M Y') }}
                        </td>
                        <td class="px-6 py-4 flex justify-end gap-3">
                            <a href="{{ route('admin.users.show', $user->id) }}" class="text-indigo-400 hover:text-indigo-300 text-sm font-medium">Detail</a>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="4">
                            @include('admin.partials.empty-state', [
                                'title'   => 'User tidak ditemukan',
                                'message' => 'Coba gunakan kata kunci pencarian yang berbeda.',
                            ])
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        {{-- Pagination --}}
        @if($users->hasPages())
        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900">
            {{ $users->links() }}
        </div>
        @endif
    </div>
</div>
@endsection
