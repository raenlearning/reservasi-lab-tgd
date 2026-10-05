<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Autentikasi berbasis token (Laravel Sanctum).
 *
 * Menggantikan Firebase Authentication. Keuntungannya untuk kasus ini: login
 * bisa memakai NIM/NIDN langsung, tanpa perlu mengakali email internal seperti
 * yang diwajibkan Firebase Auth.
 */
class AuthController extends Controller
{
    /**
     * Masuk dan terbitkan token.
     *
     * POST /api/login
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('nomor_identitas', $request->validated('nomor_identitas'))
            ->first();

        // Pesan galat sengaja sama untuk "akun tidak ada" dan "sandi salah",
        // supaya tidak membocorkan NIM/NIDN mana yang terdaftar.
        if (! $user || ! Hash::check($request->validated('password'), $user->password)) {
            throw ValidationException::withMessages([
                'nomor_identitas' => ['NIM/NIDN atau kata sandi salah.'],
            ]);
        }

        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'nomor_identitas' => ['Akun Anda dinonaktifkan. Hubungi Kepala Laboratorium.'],
            ]);
        }

        // Satu token per perangkat. Nama perangkat memudahkan pencabutan token
        // tertentu tanpa mengeluarkan pengguna dari semua perangkat.
        $token = $user->createToken(
            $request->validated('device_name') ?? 'mobile'
        )->plainTextToken;

        return response()->json([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => new UserResource($user),
        ]);
    }

    /**
     * Mendaftarkan akun Mahasiswa / Dosen baru.
     *
     * Token langsung diterbitkan supaya klien tidak perlu memanggil `/login`
     * lagi setelah pendaftaran berhasil.
     *
     * Peran Kepala Laboratorium tidak dapat dipilih di sini — lihat
     * [RegisterRequest].
     *
     * POST /api/register
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'nomor_identitas' => $request->validated('nomor_identitas'),
            'nama' => $request->validated('nama'),
            'jabatan' => $request->validated('jabatan'),
            // Di-hash otomatis oleh cast 'hashed' pada model User.
            'password' => $request->validated('password'),
            'is_active' => true,
        ]);

        $token = $user->createToken(
            $request->validated('device_name') ?? 'mobile'
        )->plainTextToken;

        return response()->json([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => new UserResource($user),
        ], 201);
    }

    /**
     * Keluar — mencabut token yang sedang dipakai.
     *
     * POST /api/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Berhasil keluar.']);
    }

    /**
     * Profil pengguna yang sedang masuk.
     *
     * GET /api/me
     */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }
}
