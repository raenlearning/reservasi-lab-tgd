<?php

namespace App\Http\Resources;

use App\Support\Jadwal;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bentuk data pengajuan reservasi.
 *
 * `nama_pemohon` dan `nomor_identitas_pemohon` dikirim mendatar (flattened)
 * agar daftar verifikasi Kepala Laboratorium bisa menampilkan identitas pemohon
 * tanpa perlu membaca relasi satu per satu di sisi klien.
 */
class BookingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'lab_id' => $this->lab_id,
            'mata_kuliah' => $this->mata_kuliah,
            'tanggal' => $this->tanggal?->format('Y-m-d'),
            'jam_mulai' => Jadwal::tampilkan($this->jam_mulai),
            'jam_selesai' => Jadwal::tampilkan($this->jam_selesai),
            'status' => $this->status,
            'catatan' => $this->catatan,
            'alasan_penolakan' => $this->alasan_penolakan,
            'reviewed_by' => $this->reviewed_by,
            'reviewed_at' => $this->reviewed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),

            // Identitas pemohon — tersedia bila relasi `user` dimuat.
            'nama_pemohon' => $this->whenLoaded('user', fn () => $this->user->nama),
            'nomor_identitas_pemohon' => $this->whenLoaded(
                'user',
                fn () => $this->user->nomor_identitas
            ),

            'lab' => new LabResource($this->whenLoaded('lab')),
        ];
    }
}
