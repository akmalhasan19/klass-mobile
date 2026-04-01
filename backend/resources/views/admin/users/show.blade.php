@extends('admin.layouts.app')

@section('title', 'Detail Pengguna')
@section('page-title', 'Detail Pengguna')
@section('page-description', 'Informasi lengkap dan manajemen role pengguna.')

@section('content')
<div class="space-y-6">

    <div class="flex items-center justify-between">
        <a href="{{ route('admin.users.index') }}" class="inline-flex items-center text-sm font-medium text-slate-400 hover:text-white transition">
            <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
            </svg>
            Kembali ke Daftar User
        </a>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {{-- Left Col: User Info --}}
        <div class="lg:col-span-1 space-y-6">
            <div class="bg-slate-900 border border-slate-800 rounded-xl p-6">
                <div class="flex justify-center mb-4">
                    @if($user->avatar_url)
                        <img src="{{ $user->avatar_url }}" alt="Avatar" class="w-24 h-24 rounded-full object-cover ring-4 ring-slate-800">
                    @else
                        <div class="w-24 h-24 rounded-full bg-slate-800 flex items-center justify-center text-3xl font-bold text-slate-500 ring-4 ring-slate-800">
                            {{ substr($user->name, 0, 1) }}
                        </div>
                    @endif
                </div>
                <h3 class="text-lg font-bold text-center text-slate-100">{{ $user->name }}</h3>
                <p class="text-sm text-center text-slate-400 mb-6">{{ $user->email }}</p>
                
                <div class="space-y-4 text-sm divide-y divide-slate-800">
                    <div class="flex justify-between pb-2">
                        <span class="text-slate-500">Terdaftar</span>
                        <span class="text-slate-300">{{ $user->created_at->format('d M Y H:i') }}</span>
                    </div>
                    <div class="flex justify-between py-2">
                        <span class="text-slate-500">ID Pengguna</span>
                        <span class="text-slate-300 font-mono text-xs">{{ $user->id }}</span>
                    </div>
                    <div class="flex justify-between py-2">
                        <span class="text-slate-500">Current Role</span>
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {{ $user->isAdmin() ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20' : 'bg-slate-800 text-slate-300' }}">
                            {{ strtoupper($user->role) }}
                        </span>
                    </div>
                </div>
            </div>
        </div>

        {{-- Right Col: Management Actions --}}
        <div class="lg:col-span-2 space-y-6">
            <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden p-6">
                <h3 class="text-base font-semibold text-slate-200 mb-4 border-b border-slate-800 pb-2">Ubah Hak Akses (Role)</h3>
                
                <form action="{{ route('admin.users.update-role', $user->id) }}" method="POST" class="space-y-4">
                    @csrf
                    @method('PATCH')
                    
                    <div>
                        <label for="role" class="block text-sm font-medium text-slate-400 mb-2">Role Akses Panel</label>
                        <select id="role" name="role" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
                            <option value="user" {{ $user->role === 'user' ? 'selected' : '' }}>User (Pengguna Biasa / Aplikasi Mobile)</option>
                            <option value="admin" {{ $user->role === 'admin' ? 'selected' : '' }}>Admin (Pengawas & Back-Office)</option>
                        </select>
                        <p class="mt-2 text-xs text-slate-500">
                            Memberikan role "Admin" berarti pengguna tersebut diberi kunci akses untuk login ke panel ini secara bebas.
                        </p>
                    </div>

                    <div class="pt-4 flex justify-end">
                        <button type="submit" class="bg-emerald-600 hover:bg-emerald-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                            Simpan Perubahan Role
                        </button>
                    </div>
                </form>
            </div>
            
            <div class="bg-slate-900 border border-slate-800 rounded-xl shadow-sm p-6">
                <h3 class="text-base font-semibold text-slate-200 mb-4">Informasi Lanjutan</h3>
                <p class="text-sm text-slate-500">Catatan/aktivitas untuk pengguna ini dapat dilihat melalui Activity Logs pada menu Monitoring global.</p>
            </div>
        </div>
    </div>
</div>
@endsection
