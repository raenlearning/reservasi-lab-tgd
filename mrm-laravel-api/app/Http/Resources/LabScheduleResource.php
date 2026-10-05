<?php

namespace App\Http\Resources;

use App\Support\Jadwal;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bentuk data jadwal laboratorium.
 *
 * Kolom TIME MySQL bernilai `'HH:mm:ss'`, sedangkan klien memakai `'HH:mm'`.
 * Pemotongan dilakukan di sini, di satu tempat, supaya tidak ada perbedaan
 * format yang menyelinap ke berbagai endpoint.
 */
class LabScheduleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'lab_id' => $this->lab_id,
            'mata_kuliah' => $this->mata_kuliah,
            'nama_dosen' => $this->nama_dosen,
            'tanggal' => $this->tanggal?->format('Y-m-d'),
            'jam_mulai' => Jadwal::tampilkan($this->jam_mulai),
            'jam_selesai' => Jadwal::tampilkan($this->jam_selesai),
            'tipe' => $this->tipe,
            'semester' => $this->semester,
            'catatan' => $this->catatan,
            'memblokir_slot' => $this->memblokirSlot(),

            // Hanya ikut terkirim bila relasinya dimuat (whenLoaded).
            'lab' => new LabResource($this->whenLoaded('lab')),
        ];
    }
}
