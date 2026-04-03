@extends('admin.layouts.app')

@section('title', 'Homepage Configurator')

@section('page-title', 'Homepage Configurator')
@section('page-description', 'Drag and drop to curate the mobile experience.')

@section('topbar-actions')
    <span class="text-[11px] uppercase tracking-wider text-text-muted mono-text font-medium flex items-center gap-2">
        <span class="w-2 h-2 bg-primary block rounded-full"></span> Live
    </span>
    <button type="submit" form="configurator-form" class="bg-black text-white px-4 py-2 text-[12px] font-semibold uppercase tracking-wide hover:bg-gray-800 transition-colors flex items-center gap-2 border border-black">
        <span class="material-symbols-outlined" style="font-size: 16px;">save</span>
        Save Changes
    </button>
@endsection

@section('content')
<style>
/* Custom scrollbar for mobile frame */
.mobile-frame-scroll::-webkit-scrollbar {
    width: 4px;
}
.mobile-frame-scroll::-webkit-scrollbar-track {
    background: transparent;
}
.mobile-frame-scroll::-webkit-scrollbar-thumb {
    background: #E5E7EB;
}
</style>

<!-- Configurator Workspace -->
<div class="h-full w-full overflow-y-auto overflow-x-hidden p-4 lg:p-8 bg-[#F9FAFB] flex flex-col">
    <form id="configurator-form" method="POST" action="{{ route('admin.homepage-sections.update') }}" class="max-w-[1200px] w-full mx-auto h-auto lg:h-full flex flex-col lg:flex-row gap-8 items-center lg:items-start pb-12 lg:pb-0">
        @csrf
        @method('PATCH')
        
        <!-- Left Pane: Component List -->
        <div class="w-full lg:w-[480px] flex flex-col h-[500px] lg:h-full bg-surface border border-border shadow-sm shrink-0">
            <div class="p-4 border-b border-border bg-gray-50 flex items-center justify-between">
                <h3 class="text-[13px] font-semibold uppercase tracking-wide text-text-main flex items-center gap-2">
                    <span class="material-symbols-outlined" style="font-size: 16px;">list</span>
                    Active Sections
                </h3>
                <span class="text-[11px] mono-text text-text-muted">{{ count($sections) }} ITEMS</span>
            </div>
            
            <div class="flex-1 overflow-y-auto p-4 space-y-3">
                @forelse($sections as $index => $section)
                    <!-- Hidden inputs so the form still submits data -->
                    <input type="hidden" name="sections[{{ $index }}][id]" value="{{ $section->id }}">
                    <input type="hidden" name="sections[{{ $index }}][position]" value="{{ $section->position }}">
                    <input type="hidden" name="sections[{{ $index }}][label]" value="{{ $section->label }}">
                    <input type="hidden" name="sections[{{ $index }}][is_enabled]" value="{{ $section->is_enabled ? '1' : '' }}">

                    <div class="group flex items-center bg-surface border {{ $section->is_enabled ? 'border-border' : 'border-dashed border-gray-300 opacity-60' }} p-3 cursor-grab hover:border-gray-400 transition-colors relative">
                        @if($section->is_enabled)
                            <div class="absolute left-0 top-0 bottom-0 w-1 bg-primary"></div>
                        @endif

                        <div class="mr-3 {{ $section->is_enabled ? 'ml-1' : '' }} text-gray-400 group-hover:text-black transition-colors flex items-center justify-center">
                            <span class="material-symbols-outlined" style="font-size: 20px;">drag_indicator</span>
                        </div>
                        <div class="flex-1">
                            <p class="text-[14px] font-semibold text-text-main">{{ $section->label }}</p>
                            <p class="text-[11px] mono-text text-text-muted mt-0.5">TYPE: {{ strtoupper($section->data_source ?? 'DEFAULT') }}</p>
                        </div>
                        
                        <div class="w-8 h-8 flex items-center justify-center text-text-muted hover:text-rose-500 cursor-pointer transition-colors border border-transparent hover:border-border hover:bg-gray-50">
                            <span class="material-symbols-outlined" style="font-size: 18px;">
                                {{ $section->is_enabled ? 'visibility' : 'visibility_off' }}
                            </span>
                        </div>
                    </div>
                @empty
                    <div class="text-[13px] text-text-muted font-medium text-center py-4">Belum ada seksi konfigurasi.</div>
                @endforelse
            </div>
            
            <div class="p-4 border-t border-border bg-gray-50">
                <button type="button" class="w-full border border-dashed border-gray-300 text-text-muted py-3 text-[13px] font-medium hover:border-black hover:text-black transition-colors flex items-center justify-center gap-2 bg-surface">
                    <span class="material-symbols-outlined" style="font-size: 16px;">add</span>
                    Add New Section
                </button>
            </div>
        </div>

        <!-- Right Pane: Mobile Preview -->
        <div class="w-full lg:flex-1 flex justify-center items-start h-[600px] lg:h-full overflow-y-auto overflow-x-hidden relative py-4 lg:py-8">
            <!-- Android Phone Layout (540x1230 Portrait) -->
            <!-- We use scale-[0.6] and negative margin to fix the bounding box for scrolling (1230 - (1230 * 0.6) = 492) -->
            <div class="relative w-[540px] h-[1230px] bg-black border-[16px] border-black overflow-hidden shadow-2xl shrink-0 rounded-[48px] scale-[0.6] origin-top" style="margin-bottom: -492px;">
                
                <!-- Mobile Status Bar -->
                <div class="h-10 bg-white w-full flex justify-between items-center px-8 pt-3 z-[60] absolute top-0 left-0 right-0 rounded-t-[32px]">
                    <span class="text-[16px] font-semibold tracking-tight">9:41</span>
                    <div class="flex gap-2.5 items-center">
                        <span class="material-symbols-outlined" style="font-size: 18px;">signal_cellular_4_bar</span>
                        <span class="material-symbols-outlined" style="font-size: 18px;">wifi</span>
                        <span class="material-symbols-outlined rotate-90" style="font-size: 18px;">battery_full</span>
                    </div>
                </div>

                <!-- App Content Area -->
                <div class="bg-[#F9FAFB] w-full h-full pt-10 overflow-y-auto mobile-frame-scroll relative">
                    
                    <!-- App Header -->
                    <div class="px-8 py-6 flex justify-between items-center bg-white sticky top-0 z-40 border-b border-gray-100">
                        <h1 class="text-3xl font-bold font-display tracking-tight">Klass.</h1>
                        <span class="material-symbols-outlined text-[28px]">search</span>
                    </div>

                    <!-- Live Preview Sections -->
                    <div class="p-6 space-y-8 pb-32">
                        <!-- Preview: Hero Banner -->
                        <div class="border border-border bg-white overflow-hidden relative group">
                            <div class="h-64 bg-gray-200 relative">
                                <div class="absolute inset-0 bg-gradient-to-tr from-emerald-100 to-blue-50"></div>
                                <div class="absolute bottom-5 left-6">
                                    <span class="bg-black text-white text-[12px] uppercase px-3 py-1 font-bold mb-2 inline-block">Featured</span>
                                    <h3 class="font-bold text-3xl leading-tight">Mastering UI/UX</h3>
                                </div>
                            </div>
                        </div>

                        <!-- Preview: Teacher Feed -->
                        <div>
                            <div class="flex justify-between items-end mb-4 px-1">
                                <h3 class="font-bold text-xl">Teacher Feed</h3>
                                <span class="text-[13px] text-gray-500 font-bold uppercase tracking-wide">View All</span>
                            </div>
                            <div class="space-y-4">
                                <div class="flex gap-5 bg-white p-5 border border-border">
                                    <div class="w-16 h-16 bg-gray-200 shrink-0"></div>
                                    <div class="flex flex-col justify-center">
                                        <h4 class="font-bold text-[18px] leading-tight mb-2">Advanced CSS Grid Layouts</h4>
                                        <p class="text-[14px] text-gray-500 mono-text">Jane Doe • 45 mins</p>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Preview: Project Recommendations -->
                        <div class="relative border-4 border-black border-dashed p-1.5 -m-1.5">
                            <div class="bg-blue-50/50 pb-3">
                                <div class="flex justify-between items-end mb-4 pt-4 px-3">
                                    <h3 class="font-bold text-xl">Recommended for you</h3>
                                </div>
                                <div class="flex gap-5 overflow-hidden pb-2 px-3">
                                    <div class="w-48 h-48 bg-white border border-border shrink-0 flex flex-col justify-end p-4">
                                        <div class="w-full h-3 bg-gray-200 mb-2.5"></div>
                                        <div class="w-2/3 h-3 bg-gray-200"></div>
                                    </div>
                                    <div class="w-48 h-48 bg-white border border-border shrink-0 flex flex-col justify-end p-4">
                                        <div class="w-full h-3 bg-gray-200 mb-2.5"></div>
                                        <div class="w-2/3 h-3 bg-gray-200"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </div>

                    <!-- Fake Bottom Nav -->
                    <div class="absolute bottom-0 w-full h-24 bg-white border-t border-gray-200 flex justify-around items-center px-6 pb-6 pt-3 z-50">
                        <span class="material-symbols-outlined text-black text-[32px]" style="font-variation-settings: 'FILL' 1;">home</span>
                        <span class="material-symbols-outlined text-gray-400 text-[32px]">explore</span>
                        <span class="material-symbols-outlined text-gray-400 text-[32px]">bookmark</span>
                        <span class="material-symbols-outlined text-gray-400 text-[32px]">person</span>
                    </div>

                </div>
            </div>
        </div>
    </form>
</div>
@endsection
