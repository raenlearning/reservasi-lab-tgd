<?php

namespace App\Http\Requests;

use App\Support\Jadwal;
use App\Http\Requests\Concerns\PesanIndonesia;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Validasi bentuk pengajuan reservasi.
 *
 * Ini pengganti blok `allow create: if ... && jam_mulai is string && ...` pada
 * `firestore.rules`. Bedanya penting: di Firestore aturan itu ditegakkan oleh
 * database dan tidak bisa dilewati; di sini ia ada di lapisan aplikasi. Karena
 * itu **setiap** endpoint tulis wajib memakai Form Request seperti ini — satu
 * controller yang lupa = celah keamanan.
 */
class StoreBookingRequest extends FormRequest
{
    use PesanIndonesia;

    public function authorize(): bool
    {
        // Hanya akun aktif yang boleh mengajukan.
        return $this->user() !== null && $this->user()->bolehMengajukan();
    }

    public function rules(): array
    {
        return [
            'lab_id' => ['required', 'integer', 'exists:labs,id'],
            'mata_kuliah' => ['required', 'string', 'min:3', 'max:100'],
            'tanggal' => [
                'required',
                'date_format:Y-m-d',
                'after_or_equal:today',
                'before_or_equal:'.now()->addDays(Jadwal::HORIZON_HARI)->format('Y-m-d'),
            ],
            'jam_mulai' => ['required', 'date_format:H:i'],
            'jam_selesai' => ['required', 'date_format:H:i', 'after:jam_mulai'],
            'catatan' => ['nullable', 'string', 'max:500'],
        ];
    }

    /**
     * Aturan yang bergantung pada beberapa field sekaligus.
     *
     * Laravel tidak punya rule bawaan untuk "durasi maksimal" atau "dalam jam
     * operasional", jadi diperiksa di sini.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;   // bentuk dasarnya sudah salah
            }

            $mulai = Jadwal::keMenit($this->input('jam_mulai'));
            $selesai = Jadwal::keMenit($this->input('jam_selesai'));

            if ($selesai - $mulai > Jadwal::MAKS_DURASI_MENIT) {
                $validator->errors()->add(
                    'jam_selesai',
                    'Durasi satu sesi maksimal '.(Jadwal::MAKS_DURASI_MENIT / 60).' jam.'
                );

                return;
            }

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
            'jam_mulai' => 'jam mulai',
            'jam_selesai' => 'jam selesai',
        ];
    }
}
