<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bentuk data pengguna yang dikirim ke klien.
 *
 * Memakai Resource, bukan mengembalikan model apa adanya, supaya `password`
 * dan kolom internal lain tidak pernah ikut terkirim — sekalipun nanti ada
 * kolom baru yang ditambahkan ke tabel.
 */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nomor_identitas' => $this->nomor_identitas,
            'nama' => $this->nama,
            'jabatan' => $this->jabatan,
            'is_active' => $this->is_active,
            'is_kepala_lab' => $this->isKepalaLab(),
        ];
    }
}
