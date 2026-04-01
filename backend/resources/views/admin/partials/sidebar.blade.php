<aside id="admin-sidebar"
    class="flex flex-col w-64 shrink-0 bg-slate-900 border-r border-slate-800 transition-all duration-300">

    {{-- Logo / Brand --}}
    <div class="flex items-center gap-3 px-6 py-5 border-b border-slate-800">
        <div class="flex items-center justify-center w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600 shadow-lg shadow-indigo-500/20">
            <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round"
                    d="M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5" />
            </svg>
        </div>
        <div>
            <span class="text-sm font-semibold text-white tracking-wide">Klass</span>
            <span class="block text-xs text-slate-400 -mt-0.5">Admin Panel</span>
        </div>
    </div>

    {{-- Navigation --}}
    <nav class="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">

        {{-- Dashboard --}}
        <x-admin.nav-item
            :href="route('admin.dashboard')"
            :active="request()->routeIs('admin.dashboard')"
            label="Dashboard"
            icon="dashboard"
        />

        {{-- Divider --}}
        <div class="pt-3 pb-1 px-3">
            <span class="text-xs font-medium text-slate-500 uppercase tracking-widest">Manajemen</span>
        </div>

        <x-admin.nav-item
            :href="route('admin.users.index')"
            :active="request()->routeIs('admin.users.*')"
            label="Pengguna"
            icon="users"
        />

        <x-admin.nav-item
            :href="route('admin.topics.index')"
            :active="request()->routeIs('admin.topics.*')"
            label="Topik Materi"
            icon="content"
        />

        <x-admin.nav-item
            :href="route('admin.contents.index')"
            :active="request()->routeIs('admin.contents.*')"
            label="Konten Modul"
            icon="content"
        />

        <x-admin.nav-item
            :href="route('admin.tasks.index')"
            :active="request()->routeIs('admin.tasks.*')"
            label="Marketplace Tasks"
            icon="tasks"
        />

        <x-admin.nav-item
            :href="route('admin.media.index')"
            :active="request()->routeIs('admin.media.*')"
            label="Media"
            icon="media"
        />

        {{-- Divider --}}
        <div class="pt-3 pb-1 px-3">
            <span class="text-xs font-medium text-slate-500 uppercase tracking-widest">Sistem</span>
        </div>

        <x-admin.nav-item
            :href="'#'"
            :active="request()->routeIs('admin.activity.*')"
            label="Activity Log"
            icon="activity"
        />

        <x-admin.nav-item
            :href="'#'"
            :active="request()->routeIs('admin.settings.*')"
            label="Pengaturan"
            icon="settings"
        />
    </nav>

    {{-- Footer sidebar: info user --}}
    <div class="px-4 py-4 border-t border-slate-800">
        <div class="flex items-center gap-3">
            <div class="flex items-center justify-center w-8 h-8 rounded-full bg-indigo-500/20 text-indigo-400 text-xs font-bold shrink-0">
                {{ strtoupper(substr(Auth::user()->name, 0, 1)) }}
            </div>
            <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-slate-200 truncate">{{ Auth::user()->name }}</p>
                <p class="text-xs text-slate-500 truncate">{{ Auth::user()->email }}</p>
            </div>
            {{-- Logout --}}
            <form method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button type="submit"
                    title="Logout"
                    class="p-1.5 rounded-lg text-slate-500 hover:text-red-400 hover:bg-red-500/10 transition-colors">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round"
                            d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75" />
                    </svg>
                </button>
            </form>
        </div>
    </div>
</aside>
