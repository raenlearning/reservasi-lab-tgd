<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Pengguna sistem.
 *
 * Login memakai `nomor_identitas` (NIM/NIDN), bukan email. Ini dimungkinkan
 * karena autentikasi kini ditangani sendiri oleh Laravel, bukan Firebase
 * Authentication yang mengharuskan email sebagai identifier.
 */
class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    public const JABATAN_MAHASISWA = 'Mahasiswa';
    public const JABATAN_DOSEN = 'Dosen';
    public const JABATAN_KEPALA_LAB = 'Kepala Lab';

    /** Jabatan yang boleh mendaftar sendiri. Kepala Lab hanya lewat seeder. */
    public const JABATAN_MENDAFTAR_SENDIRI = [
        self::JABATAN_MAHASISWA,
        self::JABATAN_DOSEN,
    ];

    protected $fillable = [
        'nomor_identitas',
        'nama',
        'password',
        'jabatan',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    // ---------------------------------------------------------------------
    // Peran
    // ---------------------------------------------------------------------

    public function isKepalaLab(): bool
    {
        return $this->jabatan === self::JABATAN_KEPALA_LAB;
    }

    public function bolehMengajukan(): bool
    {
        return $this->is_active;
    }

    // ---------------------------------------------------------------------
    // Relasi
    // ---------------------------------------------------------------------

    /** Pengajuan yang dibuat pengguna ini. */
    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    /** Pengajuan yang diverifikasi pengguna ini (Kepala Lab). */
    public function reviewedBookings(): HasMany
    {
        return $this->hasMany(Booking::class, 'reviewed_by');
    }
}
