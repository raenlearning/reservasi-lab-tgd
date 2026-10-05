<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Akun contoh untuk pengujian.
 *
 * Akun Kepala Laboratorium sengaja dibuat di sini — tidak ada jalur pendaftaran
 * mandiri untuk peran itu, karena siapa pun bisa menaikkan hak aksesnya sendiri
 * kalau boleh memilih jabatan saat mendaftar.
 */
class UserSeeder extends Seeder
{
    public function run(): void
    {
        // Kata sandi yang sama untuk semua akun demo, agar mudah diuji.
        // WAJIB diganti sebelum dipakai sungguhan.
        $sandi = 'password123';

        $akun = [
            [
                'nomor_identitas' => '2021010042',
                'nama' => 'Budi Santoso',
                'jabatan' => User::JABATAN_MAHASISWA,
            ],
            [
                'nomor_identitas' => '2021010043',
                'nama' => 'Siti Rahayu',
                'jabatan' => User::JABATAN_MAHASISWA,
            ],
            [
                'nomor_identitas' => '0012345678',
                'nama' => 'Rina Sari, M.Kom.',
                'jabatan' => User::JABATAN_DOSEN,
            ],
            [
                'nomor_identitas' => '9999000001',
                'nama' => 'Dr. Azlan, M.Kom.',
                'jabatan' => User::JABATAN_KEPALA_LAB,
            ],
        ];

        foreach ($akun as $data) {
            User::updateOrCreate(
                ['nomor_identitas' => $data['nomor_identitas']],
                [
                    'nama' => $data['nama'],
                    'jabatan' => $data['jabatan'],
                    'password' => $sandi,
                    'is_active' => true,
                ],
            );
        }

        $this->command->info('  Akun demo dibuat (kata sandi: '.$sandi.'):');
        foreach ($akun as $data) {
            $this->command->line(
                '    '.str_pad($data['nomor_identitas'], 14).$data['jabatan']
            );
        }
    }
}
