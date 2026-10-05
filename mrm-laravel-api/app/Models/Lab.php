<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Laboratorium yang dapat direservasi.
 */
class Lab extends Model
{
    use HasFactory;

    protected $fillable = [
        'nama_lab',
        'kapasitas',
        'lokasi',
        'fasilitas',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            // Kolom JSON MySQL dipetakan otomatis menjadi array PHP.
            'fasilitas' => 'array',
            'is_active' => 'boolean',
            'kapasitas' => 'integer',
        ];
    }

    public function schedules(): HasMany
    {
        return $this->hasMany(LabSchedule::class);
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    /** Hanya laboratorium aktif — dipakai saat menampilkan pilihan ke pengguna. */
    public function scopeAktif($query)
    {
        return $query->where('is_active', true);
    }
}
