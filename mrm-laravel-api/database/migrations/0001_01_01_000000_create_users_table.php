<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tabel pengguna.
 *
 * Berbeda dari tabel `users` bawaan Laravel, tabel ini **tidak memakai email**
 * sebagai identitas login. Pengguna masuk memakai NIM/NIDN langsung — sesuatu
 * yang tidak mungkin dilakukan di Firebase Authentication, dan justru menjadi
 * salah satu keuntungan pindah ke MySQL.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();

            // NIM untuk mahasiswa, NIDN untuk dosen. Unik dan dipakai untuk login.
            $table->string('nomor_identitas', 20)->unique();

            $table->string('nama', 100);

            // Hash bcrypt. Tidak pernah menyimpan kata sandi apa adanya.
            $table->string('password');

            // Menentukan hak akses. Divalidasi di Form Request, bukan hanya di UI.
            $table->enum('jabatan', ['Mahasiswa', 'Dosen', 'Kepala Lab'])
                ->default('Mahasiswa');

            // Akun nonaktif tidak boleh mengajukan reservasi.
            $table->boolean('is_active')->default(true);

            $table->rememberToken();
            $table->timestamps();

            $table->index('jabatan');
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('nomor_identitas')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('users');
    }
};
