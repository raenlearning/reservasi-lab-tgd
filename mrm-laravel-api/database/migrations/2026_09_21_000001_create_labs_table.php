<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tabel laboratorium.
 *
 * `fasilitas` disimpan sebagai JSON — MySQL 5.7+ mendukung tipe ini secara
 * native, sehingga daftar fasilitas tidak perlu tabel terpisah yang hanya akan
 * di-`JOIN` tanpa manfaat.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('labs', function (Blueprint $table) {
            $table->id();
            $table->string('nama_lab', 100)->unique();

            // Jumlah kursi / komputer yang tersedia.
            $table->unsignedSmallInteger('kapasitas');

            $table->string('lokasi', 150)->nullable();

            // Contoh: ["40 PC", "Proyektor", "AC"]
            $table->json('fasilitas')->nullable();

            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('labs');
    }
};
