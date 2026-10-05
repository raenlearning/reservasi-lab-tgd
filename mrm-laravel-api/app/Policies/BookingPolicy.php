<?php

namespace App\Policies;

use App\Models\Booking;
use App\Models\User;

/**
 * Aturan akses pengajuan.
 *
 * Ini pengganti blok `match /bookings/{bookingId}` pada `firestore.rules`.
 * Perbedaan penting: di Firestore aturan ini ditegakkan database dan berlaku
 * otomatis; di sini ia hanya berjalan bila controller benar-benar memanggil
 * `authorize()`. Karena itu setiap controller wajib memanggilnya.
 */
class BookingPolicy
{
    /** Daftar pengajuan — isinya difilter di controller sesuai peran. */
    public function viewAny(User $user): bool
    {
        return true;
    }

    /** Pemiliknya sendiri, atau Kepala Laboratorium. */
    public function view(User $user, Booking $booking): bool
    {
        return $booking->user_id === $user->id || $user->isKepalaLab();
    }

    /** Membuat pengajuan baru — hanya akun aktif. */
    public function create(User $user): bool
    {
        return $user->bolehMengajukan();
    }

    /**
     * Memverifikasi pengajuan — hanya Kepala Laboratorium, dan hanya selama
     * statusnya masih Menunggu.
     */
    public function review(User $user, Booking $booking): bool
    {
        return $user->isKepalaLab() && ! $booking->sudahFinal();
    }

    /**
     * Membatalkan pengajuan — hanya pemiliknya, dan hanya selama masih
     * Menunggu. Pengajuan yang sudah disetujui tidak boleh dihapus, karena
     * slotnya sudah tercatat terpakai.
     */
    public function delete(User $user, Booking $booking): bool
    {
        return $booking->user_id === $user->id && ! $booking->sudahFinal();
    }
}
