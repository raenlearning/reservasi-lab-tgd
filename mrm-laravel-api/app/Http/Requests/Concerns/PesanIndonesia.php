<?php

namespace App\Http\Requests\Concerns;

/**
 * Pesan validasi berbahasa Indonesia.
 *
 * Laravel tidak menyertakan berkas terjemahan `id`, sehingga tanpa trait ini
 * pesan galat muncul sebagai kunci mentah seperti `validation.after_or_equal`
 * — tidak berguna bagi pengguna.
 *
 * Dipasang sebagai trait, bukan berkas `lang/id/validation.php` yang lengkap,
 * supaya hanya aturan yang benar-benar dipakai proyek ini yang diterjemahkan
 * dan tidak ada berkas besar yang harus dirawat.
 *
 * Nama field diisi lewat `attributes()` pada masing-masing Form Request, jadi
 * `:attribute` di sini akan terbaca alami — misalnya "mata kuliah" bukan
 * "mata_kuliah".
 */
trait PesanIndonesia
{
    public function messages(): array
    {
        return [
            'required' => ':attribute wajib diisi.',
            'string' => ':attribute harus berupa teks.',
            'integer' => ':attribute harus berupa angka bulat.',
            'numeric' => ':attribute harus berupa angka.',
            'boolean' => ':attribute harus bernilai ya atau tidak.',
            'array' => ':attribute harus berupa daftar.',
            'date' => ':attribute bukan tanggal yang valid.',
            'date_format' => 'Format :attribute tidak sesuai (gunakan :format).',
            'after' => ':attribute harus lebih besar daripada :date.',
            'after_or_equal' => ':attribute tidak boleh sebelum :date.',
            'before_or_equal' => ':attribute tidak boleh setelah :date.',
            'exists' => ':attribute yang dipilih tidak ditemukan.',
            'unique' => ':attribute sudah digunakan.',
            'in' => ':attribute yang dipilih tidak valid.',
            'confirmed' => 'Konfirmasi :attribute tidak cocok.',

            // Pesan khusus per field. Perlu dipisahkan karena aturan
            // `after_or_equal:today` menyisipkan kata "today" ke placeholder
            // `:date` — kalau dibiarkan, pesannya menjadi campur bahasa.
            'tanggal.after_or_equal' => 'Tanggal tidak boleh sebelum hari ini.',
            'tanggal.before_or_equal' => 'Tanggal terlalu jauh ke depan.',
            'tanggal.date_format' => 'Format tanggal harus YYYY-MM-DD, misalnya 2026-09-25.',
            'jam_mulai.date_format' => 'Format jam harus HH:MM, misalnya 13:00.',
            'jam_selesai.date_format' => 'Format jam harus HH:MM, misalnya 15:30.',
            'jam_selesai.after' => 'Jam selesai harus lebih besar daripada jam mulai.',
            'disetujui.required' => 'Keputusan verifikasi wajib diisi.',
            'password.required' => 'Kata sandi wajib diisi.',
            'nomor_identitas.required' => 'NIM/NIDN wajib diisi.',

            'min' => [
                'string' => ':attribute minimal :min karakter.',
                'numeric' => ':attribute minimal :min.',
                'array' => ':attribute minimal berisi :min item.',
            ],
            'max' => [
                'string' => ':attribute maksimal :max karakter.',
                'numeric' => ':attribute maksimal :max.',
                'array' => ':attribute maksimal berisi :max item.',
            ],
        ];
    }
}
