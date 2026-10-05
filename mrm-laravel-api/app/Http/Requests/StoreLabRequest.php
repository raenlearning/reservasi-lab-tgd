<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\PesanIndonesia;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Tambah / ubah laboratorium. Hanya Kepala Laboratorium.
 */
class StoreLabRequest extends FormRequest
{
    use PesanIndonesia;

    public function authorize(): bool
    {
        return $this->user()?->jabatan === User::JABATAN_KEPALA_LAB;
    }

    public function rules(): array
    {
        // Saat mengubah, pengecekan unik harus mengabaikan baris ini sendiri.
        $labId = $this->route('lab')?->id;

        return [
            'nama_lab' => [
                'required', 'string', 'min:3', 'max:100',
                Rule::unique('labs', 'nama_lab')->ignore($labId),
            ],
            'kapasitas' => ['required', 'integer', 'min:1', 'max:1000'],
            'lokasi' => ['nullable', 'string', 'max:150'],
            'fasilitas' => ['nullable', 'array'],
            'fasilitas.*' => ['string', 'max:60'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }

    public function attributes(): array
    {
        return [
            'nama_lab' => 'nama laboratorium',
            'kapasitas' => 'kapasitas',
            'lokasi' => 'lokasi',
            'fasilitas' => 'fasilitas',
            'is_active' => 'status aktif',
        ];
    }
}
