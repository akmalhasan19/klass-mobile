{{--
    Admin Empty State
    Usage: @include('admin.partials.empty-state', [
        'title'   => 'Belum ada data',
        'message' => 'Belum ada pengguna yang terdaftar.',
        'icon'    => 'users',   // optional
    ])
--}}
<div class="flex flex-col items-center justify-center py-16 text-center">
    <div class="flex items-center justify-center w-14 h-14 rounded-2xl bg-slate-800 mb-4">
        <svg class="w-7 h-7 text-slate-500" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
        </svg>
    </div>
    <h3 class="text-sm font-semibold text-slate-300 mb-1">{{ $title ?? 'Belum ada data' }}</h3>
    <p class="text-sm text-slate-500 max-w-xs">{{ $message ?? 'Tidak ada item yang tersedia saat ini.' }}</p>
</div>
