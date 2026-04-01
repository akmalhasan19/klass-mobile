@extends('admin.layouts.app')

@section('title', 'Edit Konten')
@section('page-title', 'Edit Konten')
@section('page-description', 'Ubah detail dan relasi materi pelajaran.')

@section('content')
<div class="space-y-6">

    <div class="flex items-center justify-between">
        <a href="{{ route('admin.contents.index') }}" class="inline-flex items-center text-sm font-medium text-slate-400 hover:text-white transition">
            <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
            </svg>
            Kembali ke Daftar Konten
        </a>
    </div>

    <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden max-w-2xl">
        <div class="px-6 py-4 border-b border-slate-800">
            <h3 class="text-base font-semibold text-slate-200">Informasi Konten</h3>
        </div>
        
        <form action="{{ route('admin.contents.update', $content->id) }}" method="POST" class="p-6 space-y-6">
            @csrf
            @method('PATCH')
            
            <div>
                <label for="title" class="block text-sm font-medium text-slate-400 mb-2">Judul Konten</label>
                <input type="text" id="title" name="title" value="{{ old('title', $content->title) }}" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" required>
                @error('title')
                    <p class="mt-1 text-xs text-red-500">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="topic_id" class="block text-sm font-medium text-slate-400 mb-2">Pilih Induk Topik</label>
                <select id="topic_id" name="topic_id" class="bg-slate-950 border border-slate-700 text-slate-200 text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" required>
                    @foreach($topics as $topic)
                        <option value="{{ $topic->id }}" {{ old('topic_id', $content->topic_id) == $topic->id ? 'selected' : '' }}>
                            {{ $topic->title }}
                        </option>
                    @endforeach
                </select>
                @error('topic_id')
                    <p class="mt-1 text-xs text-red-500">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="is_published" class="flex items-center gap-3 cursor-pointer">
                    <input type="checkbox" id="is_published" name="is_published" value="1" class="w-5 h-5 text-indigo-600 bg-slate-950 border-slate-700 rounded focus:ring-indigo-500 focus:ring-opacity-25" {{ old('is_published', $content->is_published) ? 'checked' : '' }}>
                    <span class="text-sm font-medium text-slate-300">Publish (Konten dapat dibaca oleh student)</span>
                </label>
            </div>

            <div class="pt-4 flex justify-end gap-3 border-t border-slate-800">
                <a href="{{ route('admin.contents.index') }}" class="bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium rounded-lg text-sm px-5 py-2.5 transition">
                    Batal
                </a>
                <button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg text-sm px-5 py-2.5 transition">
                    Simpan Perubahan
                </button>
            </div>
        </form>
    </div>
</div>
@endsection
