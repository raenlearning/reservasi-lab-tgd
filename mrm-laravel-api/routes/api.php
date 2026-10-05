<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BookingController;
use App\Http\Controllers\Api\CalendarController;
use App\Http\Controllers\Api\LabController;
use App\Http\Controllers\Api\LabScheduleController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Rute API
|--------------------------------------------------------------------------
|
| Seluruh rute di sini otomatis berawalan `/api`.
|
| Autentikasi memakai token Bearer Laravel Sanctum. Middleware `auth:sanctum`
| menolak permintaan tanpa token yang sah dengan HTTP 401.
|
| Otorisasi peran TIDAK dilakukan di sini, melainkan di Form Request dan
| Policy masing-masing controller. Alasannya: memeriksa peran di lapisan rute
| cenderung terlewat ketika ada endpoint baru ditambahkan.
|
*/

// ---------------------------------------------------------------------------
// Publik
// ---------------------------------------------------------------------------

Route::post('/login', [AuthController::class, 'login']);

// Pendaftaran mandiri untuk Mahasiswa / Dosen. Peran Kepala Laboratorium tidak
// dapat dipilih klien — divalidasi di RegisterRequest.
Route::post('/register', [AuthController::class, 'register']);

// ---------------------------------------------------------------------------
// Perlu token yang sah
// ---------------------------------------------------------------------------

Route::middleware('auth:sanctum')->group(function () {

    // --- Sesi --------------------------------------------------------------
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // --- Kalender ketersediaan ---------------------------------------------
    // Satu permintaan memuat laboratorium, jadwal, dan slot terpakai sekaligus
    // agar siklus polling hanya menghasilkan satu panggilan HTTP.
    Route::get('/calendar', [CalendarController::class, 'index']);

    // --- Laboratorium -------------------------------------------------------
    Route::get('/labs', [LabController::class, 'index']);
    Route::get('/labs/{lab}', [LabController::class, 'show']);
    Route::post('/labs', [LabController::class, 'store']);
    Route::put('/labs/{lab}', [LabController::class, 'update']);
    Route::delete('/labs/{lab}', [LabController::class, 'destroy']);

    // --- Jadwal acuan -------------------------------------------------------
    Route::get('/schedules', [LabScheduleController::class, 'index']);
    Route::post('/schedules', [LabScheduleController::class, 'store']);
    Route::put('/schedules/{schedule}', [LabScheduleController::class, 'update']);
    Route::delete('/schedules/{schedule}', [LabScheduleController::class, 'destroy']);

    // --- Pengajuan reservasi ------------------------------------------------
    Route::get('/bookings', [BookingController::class, 'index']);
    Route::post('/bookings', [BookingController::class, 'store']);
    Route::patch('/bookings/{booking}/review', [BookingController::class, 'review']);
    Route::delete('/bookings/{booking}', [BookingController::class, 'destroy']);
});
