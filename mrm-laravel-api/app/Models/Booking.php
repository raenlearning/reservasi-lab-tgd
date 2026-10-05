<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Pengajuan reservasi kelas pengganti.
 */
class Booking extends Model
{
    use HasFactory;

    public const STATUS_MENUNGGU = 'Menunggu';
    public const STATUS_DISETUJUI = 'Disetujui';
    public const STATUS_DITOLAK = 'Ditolak';

    protected $fillable = [
        'user_id',
        'lab_id',
        'mata_kuliah',
        'tanggal',
        'jam_mulai',
        'jam_selesai',
        'status',
        'catatan',
        'alasan_penolakan',
        'reviewed_by',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'tanggal' => 'date:Y-m-d',
            'reviewed_at' => 'datetime',
        ];
    }

    // ---------------------------------------------------------------------
    // Relasi
    // ---------------------------------------------------------------------

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function lab(): BelongsTo
    {
        return $this->belongsTo(Lab::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    // ---------------------------------------------------------------------
    // Status
    // ---------------------------------------------------------------------

    public function sudahFinal(): bool
    {
        return $this->status !== self::STATUS_MENUNGGU;
    }

    // ---------------------------------------------------------------------
    // Scope
    // ---------------------------------------------------------------------

    /**
     * Pengajuan yang **menahan** slot.
     *
     * Status `Menunggu` ikut menahan, bukan hanya `Disetujui`. Ini disengaja:
     * begitu seseorang mengajukan sebuah slot, slot itu terkunci baginya sampai
     * Kepala Laboratorium memutuskan. Dengan begitu tidak akan pernah ada dua
     * pengajuan aktif pada jam yang sama — inti dari pencegahan double booking.
     *
     * Konsekuensinya berbeda dari versi Firebase, yang membiarkan beberapa
     * pengajuan menunggu pada slot yang sama lalu membiarkan Kepala Laboratorium
     * memilih. Model "satu slot, satu pengajuan aktif" lebih mudah dijelaskan
     * dan tidak membuat pengguna bingung ketika pengajuannya kalah tanpa alasan
     * yang jelas.
     *
     * Pengajuan `Ditolak` otomatis melepas slotnya kembali.
     */
    public function scopeMenahanSlot($query)
    {
        return $query->whereIn('status', [
            self::STATUS_MENUNGGU,
            self::STATUS_DISETUJUI,
        ]);
    }

    /** Hanya yang sudah disetujui — dipakai saat menampilkan jadwal final. */
    public function scopeDisetujui($query)
    {
        return $query->where('status', self::STATUS_DISETUJUI);
    }

    public function scopeMenunggu($query)
    {
        return $query->where('status', self::STATUS_MENUNGGU);
    }
}
