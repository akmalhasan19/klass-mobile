<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Http\Traits\ApiResponseTrait;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

/**
 * AuthController
 *
 * Menangani registrasi, login, logout, dan info user saat ini.
 *
 * POST   /api/auth/register  — Registrasi user baru
 * POST   /api/auth/login     — Login, return Sanctum token
 * POST   /api/auth/logout    — Logout, revoke token
 * GET    /api/auth/me        — Data user yang sedang login
 */
class AuthController extends Controller
{
    use ApiResponseTrait;

    /**
     * Registrasi user baru.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
        ]);

        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->created([
            'user' => new UserResource($user),
            'token' => $token,
        ], 'Registrasi berhasil.');
    }

    /**
     * Login user.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        if (!Auth::attempt($request->only('email', 'password'))) {
            return $this->error('Email atau password salah.', 401);
        }

        /** @var User $user */
        $user = Auth::user();
        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->success([
            'user' => new UserResource($user),
            'token' => $token,
        ], 'Login berhasil.');
    }

    /**
     * Logout — revoke current token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->success(null, 'Logout berhasil.');
    }

    /**
     * Info user yang sedang login.
     */
    public function me(Request $request): JsonResponse
    {
        return $this->success(
            new UserResource($request->user()),
            'Data user berhasil diambil.',
        );
    }
}
