<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

/**
 * Urutan seeding penting:
 *
 *   1. `users`   — akun demo, termasuk Kepala Laboratorium
 *   2. `labs`    — laboratorium
 *   3. `lab_schedules` — jadwal, membutuhkan `labs` sudah ada (foreign key)
 *
 * Tidak ada seeder `bookings`. Pengajuan sengaja dibiarkan kosong supaya alur
 * pengajuan dapat diuji dari nol lewat aplikasi.
 */
class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $this->command->info('Mengisi data awal...');

        $this->call([
            UserSeeder::class,
            LabSeeder::class,
            LabScheduleSeeder::class,
        ]);

        $this->command->newLine();
        $this->command->info('Selesai. Masuk ke aplikasi memakai NIM/NIDN di atas.');
    }
}
