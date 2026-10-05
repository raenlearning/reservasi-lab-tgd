<?php

namespace Database\Seeders;

use App\Models\Lab;
use App\Models\LabSchedule;
use App\Support\Jadwal;
use Illuminate\Database\Seeder;

/**
 * Jadwal praktikum contoh.
 *
 * Mengisi beberapa minggu ke depan mengikuti pola mingguan, supaya kalender
 * ketersediaan langsung ada isinya saat aplikasi pertama dibuka.
 */
class LabScheduleSeeder extends Seeder
{
    /** Jumlah hari ke depan yang diisi. */
    private const HARI = 21;

    /**
     * Pola jadwal mingguan.
     *
     * `hari` mengikuti konvensi Carbon: 0 = Minggu, 1 = Senin, ..., 6 = Sabtu.
     */
    private const POLA = [
        // Senin
        [1, 'Lab Komputer 1', '08:00', '10:30', 'Algoritma dan Pemrograman', 'Dr. Azlan, M.Kom.'],
        [1, 'Lab Komputer 2', '10:30', '13:00', 'Basis Data', 'Rina Sari, M.Kom.'],
        [1, 'Lab Jaringan', '13:00', '15:30', 'Jaringan Komputer', 'Budi Hartono, M.T.'],

        // Selasa
        [2, 'Lab Pemrograman', '08:00', '10:30', 'Pemrograman Web', 'Siti Aminah, M.Kom.'],
        [2, 'Lab Multimedia', '10:30', '13:00', 'Desain Grafis', 'Andi Pratama, M.Ds.'],
        [2, 'Lab Komputer 1', '15:30', '18:00', 'Struktur Data', 'Dr. Azlan, M.Kom.'],

        // Rabu
        [3, 'Lab Komputer 2', '08:00', '10:30', 'Sistem Operasi', 'Hendra Wijaya, M.Kom.'],
        [3, 'Lab Pemrograman', '10:30', '13:00', 'Pemrograman Mobile', 'Siti Aminah, M.Kom.'],
        [3, 'Lab Jaringan', '13:00', '15:30', 'Keamanan Jaringan', 'Budi Hartono, M.T.'],

        // Kamis
        [4, 'Lab Komputer 1', '08:00', '10:30', 'Kecerdasan Buatan', 'Dr. Azlan, M.Kom.'],
        [4, 'Lab Multimedia', '13:00', '15:30', 'Animasi Digital', 'Andi Pratama, M.Ds.'],

        // Jumat
        [5, 'Lab Komputer 2', '08:00', '10:30', 'Rekayasa Perangkat Lunak', 'Rina Sari, M.Kom.'],
        [5, 'Lab Pemrograman', '13:00', '15:30', 'Pemrograman Mobile', 'Siti Aminah, M.Kom.'],

        // Sabtu
        [6, 'Lab Komputer 1', '08:00', '10:30', 'Praktikum Basis Data Lanjut', 'Hendra Wijaya, M.Kom.'],
    ];

    public function run(): void
    {
        $labId = Lab::pluck('id', 'nama_lab');
        $semester = $this->semesterAktif();
        $jumlah = 0;

        for ($offset = 0; $offset < self::HARI; $offset++) {
            $tanggal = now()->addDays($offset)->startOfDay();
            $hariKe = (int) $tanggal->dayOfWeek;

            foreach (self::POLA as [$hari, $namaLab, $mulai, $selesai, $mk, $dosen]) {
                if ($hari !== $hariKe || ! isset($labId[$namaLab])) {
                    continue;
                }

                LabSchedule::updateOrCreate(
                    [
                        'lab_id' => $labId[$namaLab],
                        'tanggal' => $tanggal->format('Y-m-d'),
                        'jam_mulai' => $mulai.':00',
                    ],
                    [
                        'mata_kuliah' => $mk,
                        'nama_dosen' => $dosen,
                        'jam_selesai' => $selesai.':00',
                        'tipe' => 'Reguler',
                        'semester' => $semester,
                    ],
                );

                $jumlah++;
            }

            // Pemeliharaan rutin setiap dua minggu pada hari Rabu.
            if ($offset % 14 === 0 && $hariKe === 3 && isset($labId['Lab Multimedia'])) {
                LabSchedule::updateOrCreate(
                    [
                        'lab_id' => $labId['Lab Multimedia'],
                        'tanggal' => $tanggal->format('Y-m-d'),
                        'jam_mulai' => '15:30:00',
                    ],
                    [
                        'mata_kuliah' => 'Pemeliharaan Perangkat Multimedia',
                        'jam_selesai' => '17:00:00',
                        'tipe' => 'Pemeliharaan',
                        'catatan' => 'Kalibrasi proyektor & pembaruan sistem',
                        'semester' => $semester,
                    ],
                );
            }
        }

        $this->command->info('  '.$jumlah.' jadwal praktikum dibuat ('.$this->hariLabel().').');
    }

    private function semesterAktif(): string
    {
        $bulan = (int) now()->month;
        $ganjil = $bulan >= 8 || $bulan <= 1;
        $tahunAwal = $bulan >= 8 ? (int) now()->year : (int) now()->year - 1;

        return ($ganjil ? 'Ganjil ' : 'Genap ').$tahunAwal.'/'.($tahunAwal + 1);
    }

    private function hariLabel(): string
    {
        return self::HARI.' hari ke depan, jam operasional '
            .Jadwal::labelJam(Jadwal::BUKA_MENIT).'-'.Jadwal::labelJam(Jadwal::TUTUP_MENIT);
    }
}
