<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\LabResource;
use App\Http\Resources\LabScheduleResource;
use App\Models\Booking;
use App\Models\Lab;
use App\Models\LabSchedule;
use App\Support\Jadwal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Kalender ketersediaan laboratorium.
 *
 * Endpoint ini sengaja dibuat terpisah dari `/api/bookings` karena dua alasan:
 *
 * 1. **Privasi.** Kalender perlu menampilkan slot mana yang terpakai, tetapi
 *    tidak boleh membocorkan identitas pemohon. Endpoint ini hanya mengirim
 *    `mata_kuliah` dan rentang waktunya — tanpa nama maupun NIM/NIDN.
 *
 * 2. **Efisiensi polling.** Klien memuat ulang kalender secara berkala
 *    (`Timer.periodic`). Dengan menggabungkan laboratorium, jadwal, dan
 *    keterisian dalam satu respons, satu siklus polling hanya menghasilkan satu
 *    permintaan HTTP, bukan tiga.
 */
class CalendarController extends Controller
{
    /**
     * GET /api/calendar?dari=YYYY-MM-DD&sampai=YYYY-MM-DD&lab_id=1
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'dari' => ['nullable', 'date_format:Y-m-d'],
            'sampai' => ['nullable', 'date_format:Y-m-d'],
            'lab_id' => ['nullable', 'integer', 'exists:labs,id'],
        ]);

        // Rentang bawaan: hari ini sampai 30 hari ke depan.
        $dari = $request->input('dari') ?? Jadwal::hariIni();
        $sampai = $request->input('sampai')
            ?? now()->addDays(30)->format('Y-m-d');

        $labId = $request->filled('lab_id') ? $request->integer('lab_id') : null;

        $labs = Lab::query()
            ->aktif()
            ->when($labId !== null, fn ($q) => $q->whereKey($labId))
            ->orderBy('nama_lab')
            ->get();

        $schedules = LabSchedule::query()
            ->with('lab')
            ->rentang($dari, $sampai)
            ->when($labId !== null, fn ($q) => $q->where('lab_id', $labId))
            ->orderBy('tanggal')
            ->orderBy('jam_mulai')
            ->get();

        // Pengajuan Menunggu ikut ditampilkan sebagai terpakai, karena ia
        // memang menahan slot. Kalau tidak ditampilkan, pengguna akan melihat
        // slot "kosong" yang sebenarnya tidak bisa diajukan — dan mengira
        // aplikasinya rusak ketika ditolak server.
        $bookings = Booking::query()
            ->menahanSlot()
            ->whereBetween('tanggal', [$dari, $sampai])
            ->when($labId !== null, fn ($q) => $q->where('lab_id', $labId))
            ->orderBy('tanggal')
            ->orderBy('jam_mulai')
            ->get();

        $userId = $request->user()->id;

        return response()->json([
            'dari' => $dari,
            'sampai' => $sampai,
            'labs' => LabResource::collection($labs),
            'schedules' => LabScheduleResource::collection($schedules),

            // Versi ringkas tanpa data pribadi pemohon.
            'bookings' => $bookings->map(fn (Booking $b) => [
                'id' => $b->id,
                'lab_id' => $b->lab_id,
                'mata_kuliah' => $b->mata_kuliah,
                'tanggal' => $b->tanggal->format('Y-m-d'),
                'jam_mulai' => Jadwal::tampilkan($b->jam_mulai),
                'jam_selesai' => Jadwal::tampilkan($b->jam_selesai),
                'status' => $b->status,
                'milik_saya' => $b->user_id === $userId,
            ])->values(),
        ]);
    }
}
