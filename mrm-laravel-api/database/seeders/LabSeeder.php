<?php

namespace Database\Seeders;

use App\Models\Lab;
use Illuminate\Database\Seeder;

/**
 * Laboratorium komputer STMIK Triguna Dharma.
 */
class LabSeeder extends Seeder
{
    public function run(): void
    {
        $labs = [
            [
                'nama_lab' => 'Lab Komputer 1',
                'kapasitas' => 40,
                'lokasi' => 'Gedung B, Lantai 1',
                'fasilitas' => ['40 PC', 'Proyektor', 'AC', 'Whiteboard'],
            ],
            [
                'nama_lab' => 'Lab Komputer 2',
                'kapasitas' => 40,
                'lokasi' => 'Gedung B, Lantai 1',
                'fasilitas' => ['40 PC', 'Proyektor', 'AC', 'Whiteboard'],
            ],
            [
                'nama_lab' => 'Lab Multimedia',
                'kapasitas' => 30,
                'lokasi' => 'Gedung B, Lantai 2',
                'fasilitas' => ['30 iMac', 'Proyektor', 'AC', 'Scanner'],
            ],
            [
                'nama_lab' => 'Lab Jaringan',
                'kapasitas' => 25,
                'lokasi' => 'Gedung C, Lantai 1',
                'fasilitas' => ['25 PC', 'Rack Cisco', 'Router', 'Switch', 'AC'],
            ],
            [
                'nama_lab' => 'Lab Pemrograman',
                'kapasitas' => 35,
                'lokasi' => 'Gedung C, Lantai 2',
                'fasilitas' => ['35 PC', 'Proyektor', 'AC', 'Whiteboard'],
            ],
        ];

        foreach ($labs as $data) {
            Lab::updateOrCreate(
                ['nama_lab' => $data['nama_lab']],
                [...$data, 'is_active' => true],
            );
        }

        $this->command->info('  '.count($labs).' laboratorium dibuat.');
    }
}
