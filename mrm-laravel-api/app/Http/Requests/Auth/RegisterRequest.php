<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\Concerns\PesanIndonesia;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Validasi pendaftaran akun Mahasiswa / Dosen.
 *
 * Jabatan dibatasi pada [User::JABATAN_MENDAFTAR_SENDIRI] — Kepala Laboratorium
 * tidak boleh dipilih sendiri, karena siapa pun bisa menaikkan hak aksesnya
 * kalau peran boleh ditentukan klien.
 */
class RegisterRequest extends FormRequest
{
    use PesanIndonesia;

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nomor_identitas' => [
                'required',
                'string',
                'digits_between:6,15',
                Rule::unique('users', 'nomor_identitas'),
            ],
            'nama' => ['required', 'string', 'min:3', 'max:100'],
            'jabatan' => ['required', 'string', Rule::in(User::JABATAN_MENDAFTAR_SENDIRI)],
            'password' => ['required', 'string', 'min:6', 'max:255', 'confirmed'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function attributes(): array
    {
        return [
            'nomor_identitas' => 'NIM/NIDN',
            'nama' => 'nama lengkap',
            'jabatan' => 'jabatan',
            'password' => 'kata sandi',
        ];
    }
}
