<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\PesanIndonesia;
use App\Models\User;
use App\Support\Jadwal;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Tambah / ubah jadwal acuan laboratorium. Hanya Kepala Laboratorium.
 */
class StoreLabScheduleRequest extends FormRequest
{
    use PesanIndonesia;

    public function authorize(): bool
    {
        return $this->user()?->jabatan === User::JABATAN_KEPALA_LAB;
    }

    public function rules(): array
    {
        return [
            'lab_id' => ['required', 'integer', 'exists:labs,id'],
            'mata_kuliah' => ['required', 'string', 'min:3', 'max:100'],
            'nama_dosen' => ['nullable', 'string', 'max:100'],
            'tanggal' => ['required', 'date_format:Y-m-d'],

            // Bila diisi, jadwal dibuat berulang setiap 7 hari dari `tanggal`
            // sampai tanggal ini. Satu baris tetap dibuat per tanggal — kolom
            // `tanggal` bertipe DATE dan tidak menyimpan pola pengulangan.
            'ulangi_sampai' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:tanggal'],

            'jam_mulai' => ['required', 'date_format:H:i'],
            'jam_selesai' => ['required', 'date_format:H:i', 'after:jam_mulai'],
            'tipe' => ['required', 'in:Reguler,Pengganti,Pemeliharaan'],
            'semester' => ['nullable', 'string', 'max:20'],
            'catatan' => ['nullable', 'string', 'max:500'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            $mulai = Jadwal::keMenit($this->input('jam_mulai'));
            $selesai = Jadwal::keMenit($this->input('jam_selesai'));

            if ($mulai < Jadwal::BUKA_MENIT || $selesai > Jadwal::TUTUP_MENIT) {
                $validator->errors()->add(
                    'jam_mulai',
                    'Jam harus berada dalam rentang operasional laboratorium '
                    .Jadwal::labelJam(Jadwal::BUKA_MENIT).' - '
                    .Jadwal::labelJam(Jadwal::TUTUP_MENIT).'.'
                );
            }
        });
    }

    public function attributes(): array
    {
        return [
            'lab_id' => 'laboratorium',
            'mata_kuliah' => 'mata kuliah',
            'nama_dosen' => 'nama dosen',
            'tanggal' => 'tanggal',
            'ulangi_sampai' => 'tanggal akhir pengulangan',
            'jam_mulai' => 'jam mulai',
            'jam_selesai' => 'jam selesai',
            'tipe' => 'jenis jadwal',
            'semester' => 'semester',
            'catatan' => 'catatan',
        ];
    }
}
