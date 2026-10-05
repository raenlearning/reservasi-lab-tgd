<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReviewBookingRequest;
use App\Http\Requests\StoreBookingRequest;
use App\Http\Resources\BookingResource;
use App\Models\Booking;
use App\Models\LabSchedule;
use App\Support\Jadwal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Pengajuan reservasi kelas pengganti.
 *
 * ### Pencegahan double booking
 *
 * Seluruh pemeriksaan bentrok berjalan **di dalam `DB::transaction`** dengan
 * `lockForUpdate()`. Ini pengganti mekanisme `slot_locks` yang dipakai di
 * Firebase.
 *
 * Di Firebase, kunci keterisian slot terpaksa dibuat karena SDK Flutter tidak
 * bisa menjalankan `Query` di dalam transaksi. Di MySQL tidak ada keterbatasan
 * itu: `SELECT ... FOR UPDATE` pada rentang yang terindeks akan mengambil
 * *gap lock* (InnoDB, REPEATABLE READ), sehingga baris baru tidak bisa
 * disisipkan di tengah rentang tersebut. Dua permintaan yang datang bersamaan
 * akan diserialisasi oleh database, bukan oleh logika aplikasi.
 *
 * Konsekuensinya: indeks `(lab_id, tanggal, status)` pada tabel `bookings`
 * **wajib ada**. Tanpa indeks itu, penguncian melebar ke seluruh tabel dan
 * celah balapan bisa terbuka kembali.
 */
class BookingController extends Controller
{
    /**
     * Daftar pengajuan.
     *
     * Mahasiswa/Dosen hanya melihat pengajuannya sendiri; Kepala Laboratorium
     * melihat semuanya.
     *
     * GET /api/bookings
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();

        $query = Booking::query()->with('lab');

        if (! $user->isKepalaLab()) {
            // Batas akses utama: pengguna biasa tidak pernah bisa melihat
            // pengajuan orang lain lewat endpoint ini.
            $query->where('user_id', $user->id);
        } else {
            // Kepala Laboratorium perlu identitas pemohon untuk verifikasi.
            $query->with('user');
        }

        $query
            ->when(
                $request->filled('status'),
                fn ($q) => $q->where('status', $request->string('status'))
            )
            ->when(
                $request->filled('lab_id'),
                fn ($q) => $q->where('lab_id', $request->integer('lab_id'))
            )
            ->when(
                $request->filled('tanggal'),
                fn ($q) => $q->where('tanggal', $request->string('tanggal'))
            )
            ->when(
                $request->filled('dari'),
                fn ($q) => $q->where('tanggal', '>=', $request->string('dari'))
            )
            ->when(
                $request->filled('sampai'),
                fn ($q) => $q->where('tanggal', '<=', $request->string('sampai'))
            );

        return BookingResource::collection(
            $query->orderByDesc('created_at')->get()
        );
    }

    /**
     * Membuat pengajuan baru.
     *
     * Mengembalikan **201** dengan status awal `Menunggu` bila berhasil, dan
     * **422** bila slot waktu sudah terpakai.
     *
     * POST /api/bookings
     */
    public function store(StoreBookingRequest $request): JsonResponse
    {
        $this->authorize('create', Booking::class);

        $data = $request->validated();

        // Seragamkan ke 'HH:mm:ss' supaya perbandingan di query konsisten.
        $mulai = Jadwal::normalisasi($data['jam_mulai']);
        $selesai = Jadwal::normalisasi($data['jam_selesai']);

        $booking = DB::transaction(function () use ($data, $request, $mulai, $selesai) {
            $this->pastikanSlotKosong(
                labId: (int) $data['lab_id'],
                tanggal: $data['tanggal'],
                mulai: $mulai,
                selesai: $selesai,
            );

            return Booking::create([
                'user_id' => $request->user()->id,
                'lab_id' => $data['lab_id'],
                'mata_kuliah' => $data['mata_kuliah'],
                'tanggal' => $data['tanggal'],
                'jam_mulai' => $mulai,
                'jam_selesai' => $selesai,
                // Status awal ditetapkan server. Klien tidak boleh menentukan ini.
                'status' => Booking::STATUS_MENUNGGU,
                'catatan' => $data['catatan'] ?? null,
            ]);
        });

        return (new BookingResource($booking->load(['lab', 'user'])))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Menyetujui atau menolak pengajuan.
     *
     * Saat menyetujui, slot diperiksa ulang **di dalam transaksi yang sama**
     * dengan perubahan status — sehingga dua persetujuan pada jam yang sama
     * tidak mungkin sama-sama lolos.
     *
     * PATCH /api/bookings/{booking}
     */
    public function review(ReviewBookingRequest $request, Booking $booking): JsonResponse
    {
        $this->authorize('review', $booking);

        $disetujui = filter_var($request->input('disetujui'), FILTER_VALIDATE_BOOLEAN);

        $hasil = DB::transaction(function () use ($booking, $request, $disetujui) {
            // Baca ulang dengan kunci baris: mencegah dua Kepala Laboratorium
            // memverifikasi pengajuan yang sama secara bersamaan.
            $segar = Booking::query()
                ->whereKey($booking->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($segar->sudahFinal()) {
                throw ValidationException::withMessages([
                    'status' => ['Pengajuan ini sudah pernah diverifikasi.'],
                ]);
            }

            if ($disetujui) {
                // Pengajuan lain yang sudah disetujui tidak boleh beririsan.
                $this->pastikanSlotKosong(
                    labId: $segar->lab_id,
                    tanggal: $segar->tanggal->format('Y-m-d'),
                    mulai: Jadwal::normalisasi($segar->jam_mulai),
                    selesai: Jadwal::normalisasi($segar->jam_selesai),
                    kecualiBookingId: $segar->id,
                );
            }

            $segar->update([
                'status' => $disetujui
                    ? Booking::STATUS_DISETUJUI
                    : Booking::STATUS_DITOLAK,
                'alasan_penolakan' => $disetujui
                    ? null
                    : $request->input('alasan_penolakan'),
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
            ]);

            return $segar;
        });

        return (new BookingResource($hasil->load(['lab', 'user'])))->response();
    }

    /**
     * Membatalkan pengajuan yang masih menunggu.
     *
     * DELETE /api/bookings/{booking}
     */
    public function destroy(Request $request, Booking $booking): JsonResponse
    {
        $this->authorize('delete', $booking);

        $booking->delete();

        return response()->json(['message' => 'Pengajuan dibatalkan.']);
    }

    // =====================================================================
    // Pemeriksaan bentrok
    // =====================================================================

    /**
     * Memastikan sebuah rentang waktu belum ditempati, atau melempar
     * ValidationException (HTTP 422).
     *
     * **Wajib dipanggil di dalam `DB::transaction`.** `lockForUpdate()` di luar
     * transaksi tidak mengunci apa pun — ia hanya menjadi no-op, dan
     * pemeriksaan kehilangan seluruh jaminan anti-balapannya.
     *
     * Dua sumber keterisian diperiksa:
     *   1. jadwal acuan bertipe Reguler / Pemeliharaan,
     *   2. pengajuan lain yang masih aktif (Menunggu atau Disetujui).
     *
     * Status `Menunggu` **ikut** menahan slot, bukan hanya `Disetujui`. Begitu
     * seseorang mengajukan sebuah slot, slot itu terkunci sampai Kepala
     * Laboratorium memutuskan — sehingga tidak akan pernah ada dua pengajuan
     * aktif pada jam yang sama. Pengajuan `Ditolak` melepas slotnya kembali.
     *
     * @throws ValidationException selalu berisi pesan yang siap ditampilkan ke pengguna
     */
    private function pastikanSlotKosong(
        int $labId,
        string $tanggal,
        string $mulai,
        string $selesai,
        ?int $kecualiBookingId = null,
    ): void {
        // --- 1. Jadwal acuan yang memblokir ---------------------------------
        //
        // Rumus tumpang tindih: mulai < selesai_lain AND selesai > mulai_lain.
        // Rentang bersifat half-open, sehingga jadwal 08:00-10:00 dan
        // 10:00-12:00 tidak dianggap bentrok — ruangan bebas tepat pukul 10:00.
        $jadwalBentrok = LabSchedule::query()
            ->where('lab_id', $labId)
            ->where('tanggal', $tanggal)
            ->whereIn('tipe', LabSchedule::TIPE_PEMBLOKIR)
            ->where('jam_mulai', '<', $selesai)
            ->where('jam_selesai', '>', $mulai)
            ->lockForUpdate()
            ->first();

        if ($jadwalBentrok !== null) {
            throw ValidationException::withMessages([
                'jam_mulai' => [sprintf(
                    'Jadwal bentrok dengan %s %s%s pada %s - %s.',
                    mb_strtolower($jadwalBentrok->tipe),
                    $jadwalBentrok->mata_kuliah,
                    $jadwalBentrok->nama_dosen ? ' ('.$jadwalBentrok->nama_dosen.')' : '',
                    Jadwal::tampilkan($jadwalBentrok->jam_mulai),
                    Jadwal::tampilkan($jadwalBentrok->jam_selesai),
                )],
            ]);
        }

        // --- 2. Pengajuan lain yang sudah disetujui -------------------------
        $bookingBentrok = Booking::query()
            ->where('lab_id', $labId)
            ->where('tanggal', $tanggal)
            ->menahanSlot()
            ->when(
                $kecualiBookingId !== null,
                fn ($q) => $q->where('id', '!=', $kecualiBookingId)
            )
            ->where('jam_mulai', '<', $selesai)
            ->where('jam_selesai', '>', $mulai)
            ->lockForUpdate()
            ->first();

        if ($bookingBentrok !== null) {
            throw ValidationException::withMessages([
                'jam_mulai' => [sprintf(
                    'Jadwal bentrok dengan kelas pengganti %s pada %s - %s. '
                    .'Silakan pilih slot waktu lain.',
                    $bookingBentrok->mata_kuliah,
                    Jadwal::tampilkan($bookingBentrok->jam_mulai),
                    Jadwal::tampilkan($bookingBentrok->jam_selesai),
                )],
            ]);
        }
    }
}
