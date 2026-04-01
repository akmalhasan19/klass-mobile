@extends('admin.layouts.app')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard')
@section('page-description', 'Ringkasan operasional aplikasi Klass')

@section('content')
<div class="space-y-6">

    {{-- Welcome banner --}}
    <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-indigo-600 to-violet-700 p-6 shadow-lg shadow-indigo-500/20">
        <div class="relative z-10">
            <h2 class="text-lg font-semibold text-white">Selamat datang, {{ Auth::user()->name }}! 👋</h2>
            <p class="text-sm text-indigo-200 mt-1">
                Panel admin Klass siap digunakan. Data monitoring akan tersedia setelah Phase 4 selesai.
            </p>
        </div>
        {{-- Decorative circles --}}
        <div class="absolute -right-8 -top-8 w-40 h-40 rounded-full bg-white/5"></div>
        <div class="absolute -right-4 -bottom-12 w-56 h-56 rounded-full bg-white/5"></div>
    </div>

    {{-- Summary cards — placeholder, akan diisi data nyata di Phase 4 --}}
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        @foreach([
            ['label' => 'Total Pengguna',   'value' => '—', 'icon' => 'users',    'color' => 'indigo'],
            ['label' => 'Total Konten',     'value' => '—', 'icon' => 'content',  'color' => 'violet'],
            ['label' => 'Marketplace Tasks','value' => '—', 'icon' => 'tasks',    'color' => 'amber'],
            ['label' => 'File / Media',     'value' => '—', 'icon' => 'media',    'color' => 'emerald'],
        ] as $card)
        <div class="bg-slate-900 border border-slate-800 rounded-xl p-5">
            <p class="text-xs font-medium text-slate-500 uppercase tracking-wider mb-3">{{ $card['label'] }}</p>
            <p class="text-2xl font-bold text-slate-100">{{ $card['value'] }}</p>
            <p class="text-xs text-slate-600 mt-1">Tersedia setelah Phase 4</p>
        </div>
        @endforeach
    </div>

    {{-- Placeholder — Recent Activity --}}
    <div class="bg-slate-900 border border-slate-800 rounded-xl p-6">
        <h3 class="text-sm font-semibold text-slate-300 mb-4">Aktivitas Terbaru</h3>
        @include('admin.partials.empty-state', [
            'title'   => 'Belum ada aktivitas',
            'message' => 'Activity log akan tersedia setelah Phase 3 dan Phase 6 selesai diimplementasikan.',
        ])
    </div>

</div>
@endsection
