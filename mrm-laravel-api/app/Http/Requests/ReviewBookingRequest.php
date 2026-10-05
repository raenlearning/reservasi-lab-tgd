<?php

namespace App\Http\Requests;

use App\Models\User;
use App\Http\Requests\Concerns\PesanIndonesia;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ReviewBookingRequest extends FormRequest
{
    use PesanIndonesia;

    public function authorize(): bool
    {
        // Verifikasi peran di sisi server, bukan hanya menyembunyikan tombol di UI.
        return $this->user()?->jabatan === User::JABATAN_KEPALA_LAB;
    }

    public function rules(): array
    {
        return [
            'disetujui' => ['required', 'boolean'],
            // Wajib hanya bila ditolak — diperiksa di withValidator.
            'alasan_penolakan' => ['nullable', 'string', 'min:5', 'max:500'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            $disetujui = filter_var($this->input('disetujui'), FILTER_VALIDATE_BOOLEAN);

            if (! $disetujui && blank($this->input('alasan_penolakan'))) {
                $validator->errors()->add(
                    'alasan_penolakan',
                    'Alasan penolakan wajib diisi.'
                );
            }
        });
    }
}
