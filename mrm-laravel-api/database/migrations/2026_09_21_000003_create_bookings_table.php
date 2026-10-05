<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Pengajuan reservasi kelas pengganti.
 *
 * Indeks komposit `(lab_id, tanggal, status)` bukan sekadar optimasi: query
 * pemeriksaan bentrok memakai `lockForUpdate()` pada ketiga kolom tersebut.
 * Pada InnoDB dengan REPEATABLE READ, `SELECT ... FOR UPDATE` pada rentang yang
 * terindeks akan mengambil *gap lock* sehingga baris baru tidak bisa disisipkan
 * di tengah rentang itu. Tanpa indeks yang tepat, penguncian melebar ke seluruh
 * tabel dan celah balapan bisa terbuka kembali.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bookings', function (Blueprint $table) {
            $table->id();

            // Pemohon. Restrict: pengguna yang punya riwayat tidak bisa dihapus.
            $table->foreignId('user_id')
                ->constrained('users')
                ->restrictOnDelete();

            $table->foreignId('lab_id')
                ->constrained('labs')
                ->restrictOnDelete();

            $table->string('mata_kuliah', 100);

            $table->date('tanggal');
            $table->time('jam_mulai');
            $table->time('jam_selesai');

            // Status awal selalu 'Menunggu' — ditetapkan server, bukan klien.
            $table->enum('status', ['Menunggu', 'Disetujui', 'Ditolak'])
                ->default('Menunggu');

            $table->text('catatan')->nullable();
            $table->text('alasan_penolakan')->nullable();

            // Kepala Laboratorium yang memverifikasi. Null selama belum diverifikasi.
            $table->foreignId('reviewed_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamp('reviewed_at')->nullable();

            $table->timestamps();

            // Indeks untuk pemeriksaan bentrok — lihat catatan di atas.
            $table->index(['lab_id', 'tanggal', 'status']);
            $table->index(['user_id', 'created_at']);
            $table->index(['status', 'tanggal']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bookings');
    }
};
