@extends('admin.layouts.app')

@section('title', 'Homepage Configurator')

@section('page-title', 'Homepage Configurator')
@section('page-description', 'Curate the mobile experience.')

@section('content')
<div class="h-full w-full flex flex-col items-center justify-center p-8 bg-[#F9FAFB]">
    <div class="max-w-lg w-full bg-white rounded-[32px] shadow-sm border border-gray-200 p-12 text-center relative overflow-hidden">
        <!-- Decorative background elements -->
        <div class="absolute -top-24 -right-24 w-64 h-64 bg-[#529F60] opacity-10 rounded-full blur-3xl"></div>
        <div class="absolute -bottom-24 -left-24 w-64 h-64 bg-[#794517] opacity-10 rounded-full blur-3xl"></div>
        
        <!-- Icon Container -->
        <div class="w-24 h-24 bg-[#529F60]/10 rounded-[24px] flex items-center justify-center mx-auto mb-8 relative z-10 border border-[#529F60]/20">
            <span class="material-symbols-outlined text-[#529F60] text-[48px]" style="font-variation-settings: 'FILL' 1;">
                design_services
            </span>
        </div>
        
        <h2 class="text-[28px] font-bold text-[#0F172A] mb-4 relative z-10 tracking-tight" style="font-family: 'Inter', sans-serif;">
            Coming Soon
        </h2>
        
        <p class="text-[#64748B] text-[15px] leading-relaxed mb-10 relative z-10" style="font-family: 'Inter', sans-serif;">
            Kami sedang mengembangkan antarmuka <b>Homepage Configurator</b> yang jauh lebih interaktif, presisi, dan 100% akurat dengan tampilan aplikasi mobile. Fitur ini sengaja kami nonaktifkan sementara hingga pembaruan sistem berikutnya dirilis.
        </p>
        
        <a href="{{ route('admin.dashboard') }}" class="inline-flex items-center justify-center gap-2 bg-white border border-[#E2E8F0] text-[#0F172A] px-6 py-3.5 rounded-xl text-[14px] font-bold hover:bg-[#F8FAFC] transition-colors relative z-10 shadow-sm">
            <span class="material-symbols-outlined text-[20px]">arrow_back</span>
            Kembali ke Dashboard
        </a>
    </div>
</div>
@endsection