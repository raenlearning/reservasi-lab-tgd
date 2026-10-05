<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Jadwal acuan laboratorium.
 *
 * Tipe `Reguler` dan `Pemeliharaan` **memblokir** slot sehingga tidak dapat
 * diajukan sebagai kelas pengganti. Tipe `Pengganti` tidak memblokir.
 */
class LabSchedule extends Model
{
    use HasFactory;

    /** Tipe yang memblokir slot. Dipakai di query pemeriksaan bentrok. */
    public const TIPE_PEMBLOKIR = ['Reguler', 'Pemeliharaan'];

    protected $fillable = [
        'lab_id',
        'mata_kuliah',
        'nama_dosen',
        'tanggal',
        'jam_mulai',
        'jam_selesai',
        'tipe',
        'semester',
        'catatan',
    ];

    protected function casts(): array
    {
        return [
            'tanggal' => 'date:Y-m-d',
        ];
    }

    public function lab(): BelongsTo
    {
        return $this->belongsTo(Lab::class);
    }

    public function memblokirSlot(): bool
    {
        return in_array($this->tipe, self::TIPE_PEMBLOKIR, true);
    }

    /** Jadwal pada rentang tanggal tertentu, untuk mengisi kalender. */
    public function scopeRentang($query, string $dari, string $sampai)
    {
        return $query->whereBetween('tanggal', [$dari, $sampai]);
    }
}
