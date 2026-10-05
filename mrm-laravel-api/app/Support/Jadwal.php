<?php

namespace App\Support;

use Carbon\Carbon;

/**
 * Aturan penjadwalan laboratorium.
 *
 * Nilai-nilai ini **harus sama** dengan konstanta di sisi Flutter
 * (`lib/core/config/app_config.dart`). Kalau salah satu diubah, ubah keduanya —
 * kalau tidak, klien akan mengira sebuah slot valid sementara server menolaknya,
 * dan pengguna melihat pesan galat yang membingungkan.
 */
class Jadwal
{
    /** Jam operasional laboratorium. */
    public const BUKA_JAM = 8;
    public const TUTUP_JAM = 21;

    public const BUKA_MENIT = self::BUKA_JAM * 60;      // 480
    public const TUTUP_MENIT = self::TUTUP_JAM * 60;    // 1260

    /** Durasi maksimum satu sesi kelas pengganti. */
    public const MAKS_DURASI_MENIT = 4 * 60;

    /** Batas hari ke depan yang boleh diajukan. */
    public const HORIZON_HARI = 60;

    /**
     * Mengubah `'HH:mm'` menjadi menit sejak tengah malam.
     *
     * Mengembalikan `-1` bila formatnya tidak dikenali, sehingga pemanggil dapat
     * memperlakukannya sebagai nilai tidak valid.
     */
    public static function keMenit(?string $jam): int
    {
        if ($jam === null || ! preg_match('/^([01]\d|2[0-3]):([0-5]\d)$/', $jam, $m)) {
            return -1;
        }

        return ((int) $m[1]) * 60 + ((int) $m[2]);
    }

    /** Menit sejak tengah malam menjadi `'HH:mm'`. */
    public static function labelJam(int $menit): string
    {
        return sprintf('%02d:%02d', intdiv($menit, 60) % 24, $menit % 60);
    }

    /**
     * Menyeragamkan `'HH:mm'` atau `'HH:mm:ss'` menjadi `'HH:mm:ss'`.
     *
     * Kolom TIME MySQL menerima keduanya, tetapi menyeragamkan lebih dulu
     * membuat perbandingan di query selalu konsisten.
     */
    public static function normalisasi(?string $jam): string
    {
        if ($jam === null) {
            return '00:00:00';
        }

        $potongan = explode(':', $jam);

        return sprintf(
            '%02d:%02d:%02d',
            (int) ($potongan[0] ?? 0),
            (int) ($potongan[1] ?? 0),
            (int) ($potongan[2] ?? 0),
        );
    }

    /** Menampilkan `'HH:mm'` dari nilai TIME MySQL (`'HH:mm:ss'`). */
    public static function tampilkan(?string $jam): ?string
    {
        return $jam === null ? null : substr($jam, 0, 5);
    }

    /** Tanggal hari ini menurut zona waktu aplikasi (WIB). */
    public static function hariIni(): string
    {
        return Carbon::now()->format('Y-m-d');
    }

    /**
     * Dua rentang `[aMulai, aSelesai)` dan `[bMulai, bSelesai)` dinyatakan
     * bentrok bila irisannya lebih dari nol menit.
     *
     * Bersinggungan tepat di batas (selesai 10:00, mulai 10:00) **tidak**
     * dianggap bentrok, karena ruangan bebas tepat pada menit itu.
     */
    public static function bentrok(int $aMulai, int $aSelesai, int $bMulai, int $bSelesai): bool
    {
        return $aMulai < $bSelesai && $bMulai < $aSelesai;
    }

    /** Daftar pilihan jam yang bisa dipakai UI untuk mengisi dropdown. */
    public static function pilihanJam(): array
    {
        $hasil = [];

        for ($menit = self::BUKA_MENIT; $menit <= self::TUTUP_MENIT; $menit += 30) {
            $hasil[] = self::labelJam($menit);
        }

        return $hasil;
    }
}
