<?php

use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome');

Route::prefix('admin')
	->middleware('admin')
	->group(function () {
		Route::get('/', function () {
			return response('Admin access foundation ready.', 200)
				->header('Content-Type', 'text/plain');
		})->name('admin.home');
	});
