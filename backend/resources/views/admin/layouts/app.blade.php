<!DOCTYPE html>
<html lang="id" class="h-full bg-slate-950">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Dashboard') — Klass Admin</title>
    <meta name="description" content="Panel administrasi Klass — kelola pengguna, konten, marketplace, dan pengaturan aplikasi.">

    {{-- Google Fonts --}}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="h-full font-['Inter',sans-serif] antialiased text-slate-100">

    <div class="flex h-full">
        {{-- Sidebar --}}
        @include('admin.partials.sidebar')

        {{-- Main Content Area --}}
        <div class="flex flex-col flex-1 min-w-0 overflow-hidden">
            {{-- Topbar --}}
            @include('admin.partials.topbar')

            {{-- Flash Messages --}}
            @include('admin.partials.flash')

            {{-- Page Content --}}
            <main class="flex-1 overflow-y-auto p-6">
                @yield('content')
            </main>
        </div>
    </div>

    @stack('scripts')
</body>
</html>
