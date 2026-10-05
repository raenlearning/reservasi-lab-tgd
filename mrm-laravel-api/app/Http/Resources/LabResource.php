<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class LabResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'nama_lab' => $this->nama_lab,
            'kapasitas' => $this->kapasitas,
            'lokasi' => $this->lokasi,
            // Casting 'array' pada model mengubah kolom JSON menjadi array PHP.
            'fasilitas' => $this->fasilitas ?? [],
            'is_active' => $this->is_active,
        ];
    }
}
