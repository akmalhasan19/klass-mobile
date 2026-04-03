<header class="px-8 py-6 border-b border-border bg-surface shrink-0 z-10 w-full">
    <div class="max-w-[1200px] mx-auto flex items-end justify-between">
        <div>
            <h2 class="text-2xl font-bold tracking-tight text-text-main">@yield('page-title', 'Dashboard')</h2>
            @hasSection('page-description')
                <p class="text-[13px] text-text-muted mt-1 font-medium">@yield('page-description')</p>
            @endif
        </div>
        <div class="flex items-center gap-4">
            <span class="text-[11px] uppercase tracking-wider text-text-muted mono-text font-medium flex items-center gap-2">
                {{ now()->translatedFormat('D, j M Y · H:i') }} WIB
            </span>
            @hasSection('topbar-actions')
                @yield('topbar-actions')
            @endif
        </div>
    </div>
</header>
