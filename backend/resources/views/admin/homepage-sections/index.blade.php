@extends('admin.layouts.app')

@section('title', 'Homepage Configurator')
@section('page-title', 'Homepage Configurator')
@section('page-description', 'Curate the mobile experience: manage sections and recommended projects.')

@section('content')
<div x-data="{ activeTab: 'projects' }" class="w-full p-6 space-y-6">

    <!-- Tabs Header -->
    <div class="border-b border-gray-200">
        <nav class="-mb-px flex space-x-8" aria-label="Tabs">
            <button @click="activeTab = 'projects'"
                :class="activeTab === 'projects' ? 'border-[#529F60] text-[#529F60]' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'"
                class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm">
                Recommended Projects
            </button>
            <button @click="activeTab = 'sections'"
                :class="activeTab === 'sections' ? 'border-[#529F60] text-[#529F60]' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'"
                class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm">
                Section Ordering
            </button>
        </nav>
    </div>

    <!-- Tab Content: Recommended Projects -->
    <div x-show="activeTab === 'projects'" class="space-y-6" style="display: none;">
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

    <!-- Tab Content: Section Ordering -->
    <div x-show="activeTab === 'sections'" class="space-y-6" style="display: none;">
        <div class="bg-white shadow rounded-lg border border-gray-200 p-6">
            <h2 class="text-lg font-bold text-gray-900 mb-4">Homepage Sections Visibility & Ordering</h2>
            <form action="{{ route('admin.homepage-sections.update') }}" method="POST">
                @csrf
                @method('PATCH')
                
                <div class="space-y-4">
                    @foreach($sections as $index => $section)
                    <div class="flex items-center gap-4 bg-gray-50 p-4 rounded-lg border border-gray-200">
                        <input type="hidden" name="sections[{{ $index }}][id]" value="{{ $section->id }}">
                        
                        <div class="flex-1">
                            <label class="block text-xs font-medium text-gray-500 uppercase">Label / Title</label>
                            <input type="text" name="sections[{{ $index }}][label]" value="{{ $section->label }}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                        </div>
                        
                        <div class="w-24">
                            <label class="block text-xs font-medium text-gray-500 uppercase">Position</label>
                            <input type="number" name="sections[{{ $index }}][position]" value="{{ $section->position }}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                        </div>
                        
                        <div class="pt-6">
                            <label class="inline-flex items-center">
                                <input type="checkbox" name="sections[{{ $index }}][is_enabled]" value="1" {{ $section->is_enabled ? 'checked' : '' }} class="rounded border-gray-300 text-[#529F60] shadow-sm focus:border-[#529F60] focus:ring focus:ring-[#529F60] focus:ring-opacity-50">
                                <span class="ml-2 text-sm text-gray-600">Enabled</span>
                            </label>
                        </div>
                    </div>
                    @endforeach
                </div>
                
                <div class="mt-6 flex justify-end">
                    <button type="submit" class="bg-[#529F60] text-white px-4 py-2 rounded-lg text-sm font-bold shadow-sm hover:bg-[#43834F]">
                        Save Configuration
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Create Project Modal -->
<div id="createProjectModal" class="hidden fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true" onclick="document.getElementById('createProjectModal').classList.add('hidden')"></div>

        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <form action="{{ route('admin.recommended-projects.store') }}" method="POST" enctype="multipart/form-data">
                @csrf
                <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                    <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4" id="modal-title">
                        Add Recommended Project
                    </h3>
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Title</label>
                            <input type="text" name="title" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Description</label>
                            <textarea name="description" rows="3" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm"></textarea>
                        </div>
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Project Type</label>
                                <input type="text" name="project_type" placeholder="e.g. mobile, web" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Ratio</label>
                                <select name="ratio" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                                    <option value="16:9">16:9</option>
                                    <option value="1:1">1:1</option>
                                    <option value="4:3">4:3</option>
                                </select>
                            </div>
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Tags (comma separated)</label>
                            <input type="text" name="tags" placeholder="e.g. Flutter, Laravel, API" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700">Thumbnail Image</label>
                            <input type="file" name="thumbnail" accept="image/*" class="mt-1 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-[#529F60] file:text-white hover:file:bg-[#43834F]">
                        </div>
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Display Priority</label>
                                <input type="number" name="display_priority" value="0" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                            </div>
                            <div class="pt-6">
                                <label class="inline-flex items-center">
                                    <input type="checkbox" name="is_active" value="1" checked class="rounded border-gray-300 text-[#529F60] shadow-sm focus:border-[#529F60] focus:ring focus:ring-[#529F60] focus:ring-opacity-50">
                                    <span class="ml-2 text-sm text-gray-600">Active</span>
                                </label>
                            </div>
                        </div>
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Starts At (optional)</label>
                                <input type="datetime-local" name="starts_at" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Ends At (optional)</label>
                                <input type="datetime-local" name="ends_at" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#529F60] focus:ring-[#529F60] sm:text-sm">
                            </div>
                        </div>
                    </div>
                </div>
                <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                    <button type="submit" class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-[#529F60] text-base font-medium text-white hover:bg-[#43834F] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#529F60] sm:ml-3 sm:w-auto sm:text-sm">
                        Save
                    </button>
                    <button type="button" onclick="document.getElementById('createProjectModal').classList.add('hidden')" class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#529F60] sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                        Cancel
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection