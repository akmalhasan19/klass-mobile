<header class="flex items-center justify-between px-6 py-4 bg-slate-900 border-b border-slate-800 shrink-0">
    {{-- Page title --}}
    <div>
        <h1 class="text-base font-semibold text-white">@yield('page-title', 'Dashboard')</h1>
        @hasSection('page-description')
            <p class="text-xs text-slate-400 mt-0.5">@yield('page-description')</p>
        @endif
    </div>

    {{-- Right side: timestamp + avatar --}}
    <div class="flex items-center gap-4">
        <span class="text-xs text-slate-500 hidden sm:block">
            {{ now()->translatedFormat('D, j M Y · H:i') }} WIB
        </span>

        <div class="flex items-center justify-center w-8 h-8 rounded-full bg-indigo-500/20 text-indigo-400 text-xs font-bold ring-1 ring-indigo-500/30">
            {{ strtoupper(substr(Auth::user()->name, 0, 1)) }}
        </div>
    </div>
</header>
