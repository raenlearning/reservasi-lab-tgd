<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreLabScheduleRequest;
use App\Http\Resources\LabScheduleResource;
use App\Models\Booking;
use App\Models\LabSchedule;
use App\Support\Jadwal;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Jadwal acuan laboratorium — diinput Kepala Laboratorium.
 *
 * Jadwal bertipe `Reguler` dan `Pemeliharaan` memblokir slot. Karena itu saat
 * menambah atau mengubahnya, sistem juga memeriksa apakah ada pengajuan yang
 * sudah disetujui pada rentang tersebut. Tanpa pemeriksaan ini, Kepala
 * Laboratorium bisa menimpa jadwal yang sudah disetujui tanpa sadar.
 */
class LabScheduleController extends Controller
{
    /**
     * Batas jumlah pengulangan mingguan dalam satu permintaan.
     *
     * Sekadar pengaman: tanpa batas, satu permintaan bisa membuat ribuan baris.
     * 53 minggu = sekitar satu tahun.
     */
    private const MAKS_PENGULANGAN_MINGGU = 53;

    /**
     * GET /api/schedules?dari=&sampai=&lab_id=
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize('viewAny', LabSchedule::class);

        $request->validate([
            'dari' => ['nullable', 'date_format:Y-m-d'],
            'sampai' => ['nullable', 'date_format:Y-m-d'],
            'lab_id' => ['nullable', 'integer', 'exists:labs,id'],
        ]);

        $dari = $request->input('dari') ?? Jadwal::hariIni();
        $sampai = $request->input('sampai') ?? now()->addDays(30)->format('Y-m-d');

        return LabScheduleResource::collection(
            LabSchedule::query()
                ->with('lab')
                ->rentang($dari, $sampai)
                ->when(
                    $request->filled('lab_id'),
                    fn ($q) => $q->where('lab_id', $request->integer('lab_id'))
                )
                ->orderBy('tanggal')
                ->orderBy('jam_mulai')
                ->get()
        );
    }

    /**
     * POST /api/schedules
     *
     * Bila `ulangi_sampai` diisi, jadwal dibuat berulang setiap 7 hari dari
     * `tanggal` sampai tanggal tersebut. Setiap kemunculan tetap menjadi baris
     * tersendiri — kolom `tanggal` bertipe DATE dan tidak menyimpan pola.
     *
     * Minggu yang bertabrakan dengan pengajuan aktif **dilewati**, bukan
     * membatalkan seluruh rentang. Membatalkan semuanya hanya karena satu
     * minggu bentrok akan memaksa Kepala Laboratorium menginput ulang dari awal;
     * daftar minggu yang dilewati dikembalikan pada field `dilewati` agar tetap
     * terlihat dan bisa ditindaklanjuti.
     */
    public function store(StoreLabScheduleRequest $request): JsonResponse
    {
        $this->authorize('create', LabSchedule::class);

        $data = $request->validated();

        $ulangiSampai = $data['ulangi_sampai'] ?? null;
        unset($data['ulangi_sampai']);

        $mulai = Jadwal::normalisasi($data['jam_mulai']);
        $selesai = Jadwal::normalisasi($data['jam_selesai']);
        $memblokir = in_array($data['tipe'], LabSchedule::TIPE_PEMBLOKIR, true);

        $tanggalAwal = Carbon::parse($data['tanggal'])->startOfDay();
        $tanggalAkhir = $ulangiSampai === null
            ? $tanggalAwal->copy()
            : Carbon::parse($ulangiSampai)->startOfDay();

        $jumlahMinggu = (int) floor(abs($tanggalAwal->diffInDays($tanggalAkhir)) / 7) + 1;

        if ($jumlahMinggu > self::MAKS_PENGULANGAN_MINGGU) {
            throw ValidationException::withMessages([
                'ulangi_sampai' => [sprintf(
                    'Pengulangan dibatasi %d minggu, sedangkan rentang yang dipilih '
                    .'mencakup %d minggu.',
                    self::MAKS_PENGULANGAN_MINGGU,
                    $jumlahMinggu,
                )],
            ]);
        }

        $dibuat = [];
        $dilewati = [];

        DB::transaction(function () use (
            $data,
            $tanggalAwal,
            $tanggalAkhir,
            $mulai,
            $selesai,
            $memblokir,
            &$dibuat,
            &$dilewati,
        ) {
            for (
                $tanggal = $tanggalAwal->copy();
                $tanggal->lte($tanggalAkhir);
                $tanggal->addDays(7)
            ) {
                $tanggalKey = $tanggal->format('Y-m-d');

                try {
                    $this->pastikanTidakMenimpaPengajuan(
                        labId: (int) $data['lab_id'],
                        tanggal: $tanggalKey,
                        mulai: $mulai,
                        selesai: $selesai,
                        memblokir: $memblokir,
                    );
                } catch (ValidationException $galat) {
                    $dilewati[] = [
                        'tanggal' => $tanggalKey,
                        'alasan' => (string) $galat->validator
                            ->errors()
                            ->first('jam_mulai'),
                    ];

                    continue;
                }

                $dibuat[] = LabSchedule::create([
                    ...$data,
                    'tanggal' => $tanggalKey,
                    'jam_mulai' => $mulai,
                    'jam_selesai' => $selesai,
                ]);
            }
        });

        $lengkap = LabSchedule::with('lab')
            ->whereIn('id', collect($dibuat)->pluck('id'))
            ->orderBy('tanggal')
            ->get();

        return response()->json([
            'data' => LabScheduleResource::collection($lengkap),
            'dilewati' => $dilewati,
        ], 201);
    }

    /**
     * PUT /api/schedules/{schedule}
     */
    public function update(
        StoreLabScheduleRequest $request,
        LabSchedule $schedule,
    ): JsonResponse {
        $this->authorize('update', LabSchedule::class);

        $data = $request->validated();

        $jadwal = DB::transaction(function () use ($data, $schedule) {
            $this->pastikanTidakMenimpaPengajuan(
                labId: (int) $data['lab_id'],
                tanggal: $data['tanggal'],
                mulai: Jadwal::normalisasi($data['jam_mulai']),
                selesai: Jadwal::normalisasi($data['jam_selesai']),
                memblokir: in_array($data['tipe'], LabSchedule::TIPE_PEMBLOKIR, true),
                kecualiScheduleId: $schedule->id,
            );

            $schedule->update([
                ...$data,
                'jam_mulai' => Jadwal::normalisasi($data['jam_mulai']),
                'jam_selesai' => Jadwal::normalisasi($data['jam_selesai']),
            ]);

            return $schedule;
        });

        return (new LabScheduleResource($jadwal->load('lab')))->response();
    }

    /**
     * DELETE /api/schedules/{schedule}
     *
     * Slot yang dibebaskan otomatis bisa diajukan kembali — tidak ada indeks
     * keterisian terpisah yang perlu diperbarui, karena semuanya dihitung dari
     * tabel ini dan tabel `bookings`.
     */
    public function destroy(LabSchedule $schedule): JsonResponse
    {
        $this->authorize('delete', LabSchedule::class);

        $schedule->delete();

        return response()->json(['message' => 'Jadwal dihapus.']);
    }

    // =====================================================================
    // Pemeriksaan bentrok
    // =====================================================================

    /**
     * Menolak jadwal yang memblokir slot bila di rentang itu sudah ada
     * pengajuan aktif (Menunggu atau Disetujui).
     *
     * Wajib dipanggil di dalam `DB::transaction` — lihat penjelasan pada
     * `BookingController::pastikanSlotKosong()`.
     */
    private function pastikanTidakMenimpaPengajuan(
        int $labId,
        string $tanggal,
        string $mulai,
        string $selesai,
        bool $memblokir,
        ?int $kecualiScheduleId = null,
    ): void {
        // Jadwal bertipe Pengganti tidak memblokir, jadi tidak mungkin menimpa.
        if (! $memblokir) {
            return;
        }

        $bentrok = Booking::query()
            ->where('lab_id', $labId)
            ->where('tanggal', $tanggal)
            ->menahanSlot()
            ->where('jam_mulai', '<', $selesai)
            ->where('jam_selesai', '>', $mulai)
            ->lockForUpdate()
            ->first();

        if ($bentrok !== null) {
            throw ValidationException::withMessages([
                'jam_mulai' => [sprintf(
                    'Tidak dapat disimpan: sudah ada pengajuan disetujui (%s, %s - %s) '
                    .'pada rentang waktu ini.',
                    $bentrok->mata_kuliah,
                    Jadwal::tampilkan($bentrok->jam_mulai),
                    Jadwal::tampilkan($bentrok->jam_selesai),
                )],
            ]);
        }
    }
}
