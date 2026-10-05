<?php

namespace App\Http\Requests\Auth;

use App\Http\Requests\Concerns\PesanIndonesia;
use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    use PesanIndonesia;

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nomor_identitas' => ['required', 'string', 'max:20'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }

    public function attributes(): array
    {
        return [
            'nomor_identitas' => 'NIM/NIDN',
        ];
    }
}
