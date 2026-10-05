<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Jadwal acuan laboratorium — diinput Kepala Laboratorium.
 *
 * Menjadi sumber data kalender ketersediaan. Jadwal bertipe `Reguler` dan
 * `Pemeliharaan` memblokir slot sehingga tidak bisa diajukan sebagai kelas
 * pengganti; `Pengganti` tidak memblokir.
 *
 * `tanggal` memakai tipe DATE dan jam memakai TIME, bukan string. Di Firebase
 * semuanya disimpan sebagai teks karena alasan zona waktu; di MySQL tipe
 * aslinya justru lebih tepat dan bisa dibandingkan langsung
 * (`jam_mulai < :selesai AND :mulai < jam_selesai`) tanpa kolom bantu menit.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lab_schedules', function (Blueprint $table) {
            $table->id();

            $table->foreignId('lab_id')
                ->constrained('labs')
                ->restrictOnDelete();   // lab yang masih punya jadwal tidak boleh dihapus

            $table->string('mata_kuliah', 100);
            $table->string('nama_dosen', 100)->nullable();

            $table->date('tanggal');
            $table->time('jam_mulai');
            $table->time('jam_selesai');

            $table->enum('tipe', ['Reguler', 'Pengganti', 'Pemeliharaan'])
                ->default('Reguler');

            $table->string('semester', 20)->nullable();
            $table->text('catatan')->nullable();

            $table->timestamps();

            // Mempercepat pencarian jadwal per laboratorium per hari.
            $table->index(['lab_id', 'tanggal']);
            $table->index('tanggal');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lab_schedules');
    }
};
