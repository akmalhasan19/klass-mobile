@extends('admin.layouts.app')

@section('title', 'Homepage Configurator')
@section('page-title', 'Homepage Configurator')
@section('page-description', 'Curate the mobile experience: manage sections and recommended projects.')

@section('content')
<div class="w-full p-6 space-y-6">

    <div class="space-y-6 block">
        <div class="flex justify-between items-center">
            <h2 class="text-lg font-bold text-gray-900">Recommended Projects (Admin Curated)</h2>
            <button onclick="document.getElementById('createProjectModal').classList.remove('hidden')" class="bg-[#529F60] text-white px-4 py-2 rounded-lg text-sm font-bold shadow-sm hover:bg-[#43834F]">
                + Add Project
            </button>
        </div>

        <div class="bg-white shadow rounded-lg border border-gray-200 overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Project</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Source</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Priority</th>
                        <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @forelse($recommendedProjects as $project)
                    <tr>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="flex items-center">
                                @if($project->thumbnail_url)
                                <img src="{{ $project->thumbnail_url }}" class="w-12 h-12 rounded object-cover mr-4" alt="Thumbnail">
                                @else
                                <div class="w-12 h-12 rounded bg-gray-100 flex items-center justify-center mr-4">
                                    <span class="material-symbols-outlined text-gray-400">image</span>
                                </div>
                                @endif
                                <div>
                                    <div class="text-sm font-medium text-gray-900">{{ $project->title }}</div>
                                    <div class="text-xs text-gray-500">{{ $project->project_type ?? 'N/A' }}</div>
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                                {{ $project->source_type }}
                            </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            @php
                                $now = now();
                                $statusLabel = 'Active';
                                $statusColor = 'bg-green-100 text-green-800';

                                if (!$project->is_active) {
                                    $statusLabel = 'Inactive';
                                    $statusColor = 'bg-gray-100 text-gray-800';
                                } elseif ($project->starts_at && $project->starts_at > $now) {
                                    $statusLabel = 'Scheduled';
                                    $statusColor = 'bg-yellow-100 text-yellow-800';
                                } elseif ($project->ends_at && $project->ends_at < $now) {
                                    $statusLabel = 'Expired';
                                    $statusColor = 'bg-red-100 text-red-800';
                                }
                            @endphp
                            <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full {{ $statusColor }}">
                                {{ $statusLabel }}
                            </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {{ $project->display_priority }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <!-- Toggle Active Form -->
                            <form action="{{ route('admin.recommended-projects.toggle-active', $project) }}" method="POST" class="inline-block">
                                @csrf
                                @method('PATCH')
                                <button type="submit" class="{{ $project->is_active ? 'text-gray-500 hover:text-gray-700' : 'text-green-600 hover:text-green-800' }} mr-2">
                                    {{ $project->is_active ? 'Deactivate' : 'Activate' }}
                                </button>
                            </form>
                            
                            <!-- Delete Form -->
                            <form action="{{ route('admin.recommended-projects.destroy', $project) }}" method="POST" class="inline-block" onsubmit="return confirm('Are you sure you want to delete this project?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="text-red-600 hover:text-red-900">Delete</button>
                            </form>
                        </td>
                    </tr>
                    @empty
                    <tr>
                        <td colspan="5" class="px-6 py-4 text-center text-sm text-gray-500">
                            No recommended projects found.
                        </td>
                    </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
</div>

<!-- Create Project Modal -->
<div id="createProjectModal" class="hidden fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <!-- Background overlay -->
    <div class="absolute inset-0" aria-hidden="true" onclick="document.getElementById('createProjectModal').classList.add('hidden')"></div>

    <div class="relative bg-white border border-slate-950 w-full max-w-2xl shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] flex flex-col max-h-[90vh]">
        <!-- Modal Header -->
        <div class="flex justify-between items-center px-4 py-3 border-b border-slate-200 bg-slate-50 shrink-0">
            <h2 class="text-sm font-bold uppercase tracking-wider text-slate-800" id="modal-title">Add Recommended Project</h2>
            <button type="button" class="text-slate-400 hover:text-slate-900 transition-colors" onclick="document.getElementById('createProjectModal').classList.add('hidden')">
                <span class="material-symbols-outlined">close</span>
            </button>
        </div>

        <!-- Modal Content (High Density Form) -->
        <form action="{{ route('admin.recommended-projects.store') }}" method="POST" enctype="multipart/form-data" class="flex flex-col overflow-hidden h-full" id="addProjectForm" onsubmit="handleProjectSubmit(event)">
            @csrf
            <div class="p-4 grid grid-cols-12 gap-y-4 gap-x-6 overflow-y-auto">
                <!-- Project Title -->
                <div class="col-span-12">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Project Title</label>
                    <input type="text" name="title" required class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none" placeholder="Enter high-level project name"/>
                </div>

                <!-- Description -->
                <div class="col-span-12">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Description</label>
                    <textarea name="description" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none h-20 resize-none" placeholder="Brief technical summary..."></textarea>
                </div>

                <!-- Project Type & Ratio -->
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Project Type</label>
                    <input type="text" name="project_type" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none" placeholder="e.g. mobile, web"/>
                </div>
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Ratio</label>
                    <select name="ratio" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none appearance-none bg-white">
                        <option value="16:9">16:9</option>
                        <option value="1:1">1:1</option>
                        <option value="4:3">4:3</option>
                    </select>
                </div>

                <!-- Tags -->
                <div class="col-span-12">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Tags (Comma Separated)</label>
                    <input type="text" name="tags" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none" placeholder="cloud, automation, security"/>
                </div>

                <!-- Thumbnail & Document -->
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Thumbnail Image</label>
                    <div class="relative border border-slate-300 p-2 flex items-center bg-slate-50 overflow-hidden h-[46px] group hover:bg-slate-100 transition-colors">
                        <input type="file" name="thumbnail" accept="image/*" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" onchange="updateFileLabel(this, 'thumb-label', 'thumb-icon', 'thumb-btn')">
                        <span class="material-symbols-outlined text-slate-400 mr-2 group-hover:text-slate-600 transition-colors" id="thumb-icon">image</span>
                        <span class="text-xs text-slate-600 truncate font-mono flex-1" id="thumb-label">Select image...</span>
                        <button class="ml-auto text-[10px] border border-slate-900 px-2 py-0.5 hover:bg-slate-200 uppercase font-bold relative z-0 shrink-0" type="button" id="thumb-btn">BROWSE</button>
                    </div>
                </div>
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Project Document</label>
                    <div class="relative border border-slate-300 p-2 flex items-center bg-slate-50 overflow-hidden h-[46px] group hover:bg-slate-100 transition-colors">
                        <input type="file" name="project_file" accept=".pdf,.ppt,.pptx,.doc,.docx" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" onchange="updateFileLabel(this, 'doc-label', 'doc-icon', 'doc-btn')">
                        <span class="material-symbols-outlined text-slate-400 mr-2 group-hover:text-slate-600 transition-colors" id="doc-icon">description</span>
                        <span class="text-xs text-slate-600 truncate font-mono flex-1" id="doc-label">Upload PDF, PPT, DOC</span>
                        <button class="ml-auto text-[10px] border border-slate-900 px-2 py-0.5 hover:bg-slate-200 uppercase font-bold relative z-0 shrink-0" type="button" id="doc-btn">UPLOAD</button>
                    </div>
                </div>

                <!-- Display Priority & Active Status -->
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Display Priority</label>
                    <input type="number" name="display_priority" value="0" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none"/>
                </div>
                <div class="col-span-6 flex items-end">
                    <label class="flex items-center gap-3 cursor-pointer h-[34px]">
                        <input type="checkbox" name="is_active" value="1" checked class="w-4 h-4 border-slate-300 text-slate-900 focus:ring-0 rounded-none"/>
                        <span class="text-[10px] font-bold uppercase text-slate-700">Project Is Active</span>
                    </label>
                </div>

                <!-- Start & End Dates -->
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Starts At (Optional)</label>
                    <div class="relative">
                        <input type="datetime-local" name="starts_at" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none"/>
                    </div>
                </div>
                <div class="col-span-6">
                    <label class="block text-[10px] font-bold uppercase text-slate-500 mb-1">Ends At (Optional)</label>
                    <div class="relative">
                        <input type="datetime-local" name="ends_at" class="w-full border border-slate-300 px-3 py-1.5 text-sm focus:ring-0 focus:border-slate-900 rounded-none"/>
                    </div>
                </div>
            </div>

            <!-- Modal Footer Actions -->
            <div class="flex items-center justify-end gap-3 px-4 py-4 border-t border-slate-200 bg-slate-50 mt-auto shrink-0">
                <button type="button" class="px-4 py-2 text-xs font-bold uppercase tracking-widest text-slate-500 bg-white border border-slate-300 hover:bg-slate-100 transition-colors" onclick="document.getElementById('createProjectModal').classList.add('hidden')">Discard</button>
                <button type="submit" id="submitProjectBtn" class="px-6 py-2 text-xs font-bold uppercase tracking-widest text-white bg-slate-950 border border-slate-950 hover:bg-slate-800 transition-colors">Save Project</button>
            </div>
        </form>
    </div>
</div>
@endsection

@push('scripts')
<script>
    function updateFileLabel(input, labelId, iconId, btnId) {
        const label = document.getElementById(labelId);
        const icon = document.getElementById(iconId);
        const btn = document.getElementById(btnId);

        if (input.files && input.files.length > 0) {
            label.textContent = input.files[0].name;
            label.classList.add('text-blue-600', 'font-bold');
            
            icon.textContent = 'check_circle';
            icon.classList.add('text-[#529F60]');
            icon.classList.remove('text-slate-400');
            
            btn.textContent = 'REPLACE';
        } else {
            label.textContent = labelId === 'thumb-label' ? 'Select image...' : 'Upload PDF, PPT, DOC';
            label.classList.remove('text-blue-600', 'font-bold');
            
            icon.textContent = labelId === 'thumb-label' ? 'image' : 'description';
            icon.classList.remove('text-[#529F60]');
            icon.classList.add('text-slate-400');
            
            btn.textContent = labelId === 'thumb-label' ? 'BROWSE' : 'UPLOAD';
        }
    }

    function handleProjectSubmit(e) {
        const btn = document.getElementById('submitProjectBtn');
        btn.innerHTML = '<span class="material-symbols-outlined text-[14px] animate-spin mr-2 align-middle">progress_activity</span> UPLOADING...';
        btn.classList.add('opacity-80', 'cursor-wait');
        btn.classList.remove('hover:bg-slate-800');
        btn.style.pointerEvents = 'none';
    }
</script>
@endpush