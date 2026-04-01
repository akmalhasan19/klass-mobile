<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\View\View;

class AdminDashboardController extends Controller
{
    /**
     * Stub dashboard admin — akan diisi data monitoring pada Phase 4.
     */
    public function index(): View
    {
        return view('admin.dashboard');
    }
}
