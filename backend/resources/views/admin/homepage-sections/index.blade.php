@extends('admin.layouts.app')

@section('title', 'Homepage Sections')
@section('page-title', 'Homepage / App Feed Sections')
@section('page-description', 'Kelola label, urutan, dan visibilitas dari section di halaman utama aplikasi mobile.')

@section('content')
<div class="space-y-6">

    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden p-6">
        <form method="POST" action="{{ route('admin.homepage-sections.update') }}">
            @csrf
            @method('PATCH')

            <div class="space-y-4">
                <p class="text-sm text-slate-400 mb-6 font-medium">Ubah urutan (Position) untuk mengatur seksi mana yang tampil lebih dulu. Section dengan centang 'Enable' akan ditampilkan di halaman depan aplikasi.</p>

                @forelse($sections as $index => $section)
                    <div class="bg-slate-950 border border-slate-800 rounded-lg p-4 flex items-center gap-6">
                        <input type="hidden" name="sections[{{ $index }}][id]" value="{{ $section->id }}">
                        
                        <div class="w-16">
                            <label class="block text-xs text-slate-500 mb-1 font-medium">Position</label>
                            <input type="number" name="sections[{{ $index }}][position]" value="{{ $section->position }}" min="1" class="w-full bg-slate-900 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 p-2 text-center">
                        </div>

                        <div class="flex-1">
                            <label class="block text-xs text-slate-500 mb-1 font-medium">Section Label</label>
                            <input type="text" name="sections[{{ $index }}][label]" value="{{ $section->label }}" class="w-full bg-slate-900 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 p-2">
                        </div>

                        <div class="w-48 text-left">
                            <label class="block text-xs text-slate-500 mb-1 font-medium">Internal Key</label>
                            <div class="text-sm text-slate-400 font-mono">{{ $section->key }}</div>
                        </div>

                        <div class="w-32 text-left">
                            <label class="block text-xs text-slate-500 mb-1 font-medium">Data Source</label>
                            <div class="text-sm text-slate-400">{{ $section->data_source }}</div>
                        </div>

                        <div class="w-24 text-center pb-2 flex flex-col items-center">
                            <label class="block text-xs text-slate-500 mb-2 font-medium">Enable</label>
                            <label class="relative inline-flex items-center cursor-pointer">
                                <input type="checkbox" name="sections[{{ $index }}][is_enabled]" class="sr-only peer" {{ $section->is_enabled ? 'checked' : '' }}>
                                <div class="w-11 h-6 bg-slate-700 peer-focus:outline-none ring-0 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                            </label>
                        </div>
                    </div>
                @empty
                    <div class="text-slate-400 italic">Belum ada seksi homepage dikonfigurasi. (Silakan seed database jika kosong)</div>
                @endforelse
            </div>

            @if($sections->isNotEmpty())
                <div class="mt-8 pt-4 border-t border-slate-800 flex justify-end">
                    <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-6 py-2.5 transition">
                        Simpan Perubahan
                    </button>
                </div>
            @endif
        </form>
    </div>

</div>
@endsection
