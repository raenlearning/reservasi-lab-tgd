# Sistem Reservasi Laboratorium Kampus

Arsitektur terpisah: **Flutter (mobile) → Laravel API (REST) → MySQL**.

Menggantikan implementasi Firebase sebelumnya. Tidak ada lagi Firebase
Authentication, Cloud Firestore, Cloud Functions, maupun FCM.

```
2026-09-19-13-44-45/
├── mrm-laravel-api/            Backend Laravel 13 + MySQL  ← BARU, siap jalan
└── mobile_resource_management/ Aplikasi Flutter            ← lapisan data sudah HTTP
```

> **Status:** backend **selesai dan terverifikasi** (8/8 uji bentrok lulus,
> otorisasi peran bekerja). Aplikasi Flutter sudah memakai HTTP untuk seluruh
> lapisan data **dan** lapisan tampilan — `flutter analyze` bersih tanpa temuan.
> Lihat [Status pengerjaan](#status-pengerjaan).

---

## Daftar isi

1. [Menjalankan backend](#1-menjalankan-backend)
2. [Konfigurasi URL di Flutter](#2-konfigurasi-url-di-flutter)
3. [Akun demo](#3-akun-demo)
4. [Peran tiap berkas](#4-peran-tiap-berkas)
5. [Rujukan API](#5-rujukan-api)
6. [Cara pencegahan double booking bekerja](#6-cara-pencegahan-double-booking-bekerja)
7. [Status pengerjaan](#status-pengerjaan)
8. [Pemecahan masalah](#7-pemecahan-masalah)

---

## 1. Menjalankan backend

Prasyarat: PHP 8.2+, Composer, MySQL 8.0+. Laragon sudah memenuhi semuanya.

```bash
cd mrm-laravel-api

# 1. Pasang dependensi (sekali saja)
composer install

# 2. Buat database
mysql -u root -e "CREATE DATABASE mrm_triguna CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"

# 3. Isi tabel + data awal
php artisan migrate:fresh --seed

# 4. Jalankan server
php artisan serve --host=0.0.0.0 --port=8000
```

**`--host=0.0.0.0` wajib.** Tanpa itu server hanya mendengarkan `127.0.0.1`,
sehingga emulator dan HP fisik tidak bisa menjangkaunya.

Berkas `.env` sudah dikonfigurasi:

```env
APP_TIMEZONE=Asia/Jakarta     # jadwal kampus memakai WIB
DB_CONNECTION=mysql
DB_DATABASE=mrm_triguna
DB_USERNAME=root
DB_PASSWORD=
```

> `APP_TIMEZONE` harus disetel **sebelum** menulis data pertama. Laravel
> default UTC — tanpa ini, jadwal 08:00 bisa terbaca sebagai 01:00.

---

## 2. Konfigurasi URL di Flutter

Ini penyebab paling umum aplikasi gagal terhubung. Nilainya berbeda tergantung
cara Anda menjalankan aplikasi.

| Cara menjalankan | Alamat yang dipakai |
|---|---|
| **Emulator Android** | `http://10.0.2.2:8000/api` |
| **HP fisik di Wi-Fi yang sama** | `http://<IP-LAPTOP>:8000/api` |
| **Chrome / desktop** | `http://127.0.0.1:8000/api` |

### Mengapa emulator memakai `10.0.2.2`

Emulator Android berjalan di dalam mesin virtual dengan jaringan tersendiri.
`127.0.0.1` **di dalam emulator** menunjuk ke emulator itu sendiri, bukan ke
laptop Anda. Android menyediakan alias khusus `10.0.2.2` yang diteruskan ke
`127.0.0.1` milik laptop.

### Cara mengetahui IP laptop

Windows (PowerShell):

```powershell
ipconfig
```

Lihat **IPv4 Address** pada adapter Wi-Fi — misalnya `192.168.1.10`.
HP dan laptop **harus tersambung ke Wi-Fi yang sama**.

### Mengubah alamat

Cara yang disarankan — tanpa mengedit berkas:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
```

Atau ubah nilai bawaannya di `lib/core/config/app_config.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',   // ← ubah di sini
);
```

### Izin cleartext Android

Android 9+ memblokir HTTP biasa secara bawaan. Manifest sudah memuat:

```xml
<application android:usesCleartextTraffic="true">
```

Tanpa ini setiap permintaan gagal dengan `CLEARTEXT communication not
permitted` — dan pesannya tidak muncul di log Flutter, sehingga sulit dilacak.
Untuk produksi, ganti dengan `networkSecurityConfig` yang hanya mengizinkan
alamat pengembangan, atau pasang TLS.

### Memastikan server terjangkau dari HP

```bash
# Di laptop
curl http://192.168.1.10:8000/api/login -X POST \
  -H "Content-Type: application/json" \
  -d '{"nomor_identitas":"2021010042","password":"password123"}'
```

Kalau perintah ini berhasil di laptop tetapi gagal di HP, biasanya
**Windows Firewall** memblokir port 8000. Izinkan lewat:

```powershell
New-NetFirewallRule -DisplayName "Laravel 8000" -Direction Inbound `
  -LocalPort 8000 -Protocol TCP -Action Allow
```

---
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
---

---

## 3. Akun demo

Dibuat oleh `UserSeeder`. Kata sandi semua akun: **`password123`**

| NIM / NIDN | Nama | Jabatan |
|---|---|---|
| `2021010042` | Budi Santoso | Mahasiswa |
| `2021010043` | Siti Rahayu | Mahasiswa |
| `0012345678` | Rina Sari, M.Kom. | Dosen |
| `9999000001` | Dr. Azlan, M.Kom. | **Kepala Lab** |

> Login memakai **NIM/NIDN**, bukan email. Ini dimungkinkan karena autentikasi
> ditangani Laravel sendiri — Firebase Authentication mengharuskan email
> sebagai identifier, sehingga versi lama terpaksa memetakan
> `2021010042` → `2021010042@trigunadharma.ac.id`.
>
> **Ganti kata sandi ini sebelum dipakai sungguhan.**

---

## 4. Peran tiap berkas

### Backend — `mrm-laravel-api/`

#### Migrasi — `database/migrations/`

| Berkas | Isi |
|---|---|
| `0001_01_01_000000_create_users_table.php` | Tabel `users`. Tanpa kolom email; login lewat `nomor_identitas` |
| `2026_09_21_000001_create_labs_table.php` | Tabel `labs`. `fasilitas` sebagai kolom JSON |
| `2026_09_21_000002_create_lab_schedules_table.php` | Tabel `lab_schedules`. `tanggal` DATE, jam TIME |
| `2026_09_21_000003_create_bookings_table.php` | Tabel `bookings` + **indeks `(lab_id, tanggal, status)`** yang wajib ada untuk `lockForUpdate` |

#### Model — `app/Models/`

| Berkas | Peran |
|---|---|
| `User.php` | Pengguna + peran. Konstanta jabatan, `isKepalaLab()` |
| `Lab.php` | Laboratorium. Casting `fasilitas` JSON → array |
| `LabSchedule.php` | Jadwal acuan. `TIPE_PEMBLOKIR`, `memblokirSlot()` |
| `Booking.php` | Pengajuan. **`scopeMenahanSlot()`** — inti pencegahan double booking |

#### Validasi — `app/Http/Requests/`

Pengganti blok `allow create: if ...` pada `firestore.rules`. Di Firestore
aturan ditegakkan database dan tidak bisa dilewati; di sini ia ada di lapisan
aplikasi, jadi **setiap endpoint tulis wajib memakai Form Request**.

| Berkas | Peran |
|---|---|
| `Auth/LoginRequest.php` | Validasi login |
| `StoreBookingRequest.php` | Validasi pengajuan + jam operasional & durasi maksimum |
| `ReviewBookingRequest.php` | Validasi verifikasi; alasan wajib bila ditolak |
| `StoreLabRequest.php` | Validasi laboratorium (hanya Kepala Lab) |
| `StoreLabScheduleRequest.php` | Validasi jadwal (hanya Kepala Lab) |
| `Concerns/PesanIndonesia.php` | Pesan validasi berbahasa Indonesia (Laravel tidak menyertakan terjemahan `id`) |

#### Controller — `app/Http/Controllers/Api/`

| Berkas | Peran |
|---|---|
| `AuthController.php` | `login`, `logout`, `me` — menerbitkan token Sanctum |
| `BookingController.php` | **Inti pencegahan double booking.** `store` mengembalikan 201/422 |
| `CalendarController.php` | Ketersediaan dalam **satu** respons — agar polling hemat |
| `LabController.php` | CRUD laboratorium |
| `LabScheduleController.php` | CRUD jadwal + cek bentrok terhadap pengajuan |

#### Policy — `app/Policies/`

Pengganti `match /bookings/{id}` pada rules. **Hanya berjalan bila controller
memanggil `authorize()`** — ini perbedaan penting dari Firestore.

| Berkas | Peran |
|---|---|
| `BookingPolicy.php` | Siapa boleh melihat, membuat, memverifikasi, membatalkan |
| `LabPolicy.php` | Hanya Kepala Lab yang boleh mengubah laboratorium |
| `LabSchedulePolicy.php` | Hanya Kepala Lab yang boleh mengubah jadwal |

#### Resource — `app/Http/Resources/`

Menentukan bentuk JSON. Mencegah kolom sensitif ikut terkirim sekalipun tabel
bertambah kolom baru.

| Berkas | Peran |
|---|---|
| `UserResource.php` | Tanpa `password` |
| `LabResource.php` | Fasilitas sebagai array |
| `LabScheduleResource.php` | `TIME` MySQL `'08:00:00'` → `'08:00'` |
| `BookingResource.php` | `nama_pemohon` mendatar untuk daftar verifikasi |

#### Pendukung

| Berkas | Peran |
|---|---|
| `app/Support/Jadwal.php` | **Aturan penjadwalan terpusat** — jam operasional, durasi maks, rumus bentrok. Harus sinkron dengan `AppConfig` di Flutter |
| `routes/api.php` | Seluruh rute. Otorisasi peran **tidak** di sini, melainkan di Policy |
| `database/seeders/` | `UserSeeder`, `LabSeeder`, `LabScheduleSeeder` |

### Frontend — `mobile_resource_management/lib/`

#### Konfigurasi & fondasi

| Berkas | Peran |
|---|---|
| `core/config/app_config.dart` | **Base URL, interval polling, aturan penjadwalan.** Berisi catatan lengkap soal `10.0.2.2` |
| `core/errors/app_exception.dart` | Memetakan status HTTP (401/403/404/422/5xx) → pesan Indonesia |
| `data/services/token_storage.dart` | Token Sanctum di `flutter_secure_storage` (setara kata sandi, bukan `shared_preferences`) |
| `data/services/api_client.dart` | Klien HTTP: sisipkan Bearer token, ubah galat, hapus token saat 401 |

#### Lapisan data

| Berkas | Peran |
|---|---|
| `data/services/auth_api.dart` | `login`, `me`, `logout` |
| `data/services/kalender_api.dart` | `GET /calendar` — satu permintaan berisi labs + jadwal + keterisian |
| `data/services/booking_api.dart` | Pengajuan + jadwal acuan |
| `data/models/app_user.dart` | Pengguna. Menyimpan `jabatan` **mentah** agar salah tulis terlihat |
| `data/models/booking.dart` | Pengajuan + `BookingDraft` (payload kirim) |
| `data/models/lab.dart`, `lab_schedule.dart` | Model lain |
| `data/models/occupancy.dart` | Menyatukan jadwal & pengajuan jadi satu bentuk slot + `computeFreeRanges()` |
| `data/providers/api_providers.dart` | Instance tunggal `ApiClient`, `TokenStorage`, dan tiap API |

#### State & polling

| Berkas | Peran |
|---|---|
| `features/auth/providers/auth_providers.dart` | `authSessionProvider` (sealed class), `currentUserProvider`, `isAdminProvider` |
| `features/calendar/providers/calendar_providers.dart` | **`Timer.periodic` short polling** + provider turunan ketersediaan |
| `features/booking/providers/booking_providers.dart` | Daftar pengajuan + aksi ajukan/verifikasi/batalkan |

---

## 5. Rujukan API

Seluruh rute berawalan `/api`. Kecuali `login`, semuanya butuh
`Authorization: Bearer <token>`.

| Metode | Rute | Akses | Keterangan |
|---|---|---|---|
| POST | `/login` | Publik | → `{token, user}` |
| POST | `/register` | Publik | Daftar Mahasiswa/Dosen → `201` + `{token, user}` |
| POST | `/logout` | Semua | Mencabut token yang dipakai |
| GET | `/me` | Semua | Profil pengguna aktif |
| GET | `/calendar?dari=&sampai=&lab_id=` | Semua | labs + schedules + bookings terpakai |
| GET | `/labs` | Semua | `?termasuk_nonaktif=1` untuk Kepala Lab |
| POST/PUT/DELETE | `/labs[/{id}]` | Kepala Lab | CRUD laboratorium |
| GET | `/schedules?dari=&sampai=&lab_id=` | Semua | Jadwal acuan |
| POST/PUT/DELETE | `/schedules[/{id}]` | Kepala Lab | CRUD jadwal |
| GET | `/bookings?status=&lab_id=&tanggal=` | Semua¹ | Mahasiswa: miliknya. Kepala Lab: semua |
| POST | `/bookings` | Akun aktif | **201** dibuat `Menunggu` · **422** slot bentrok |
| PATCH | `/bookings/{id}/review` | Kepala Lab | `{disetujui, alasan_penolakan}` |
| DELETE | `/bookings/{id}` | Pemilik | Batalkan, hanya saat `Menunggu` |

¹ Isinya otomatis difilter sesuai peran di controller.

**Bentuk galat 422** (validasi maupun bentrok):

```json
{
  "message": "Jadwal bentrok dengan kelas pengganti Pemrograman Mobile pada 08:00 - 10:00. Silakan pilih slot waktu lain.",
  "errors": { "jam_mulai": ["Jadwal bentrok dengan ..."] }
}
```

---

## 6. Cara pencegahan double booking bekerja

Seluruh pemeriksaan berjalan **di dalam `DB::transaction`** dengan
`lockForUpdate()`:

```php
$booking = DB::transaction(function () use ($data, $request) {
    // 1. Jadwal acuan yang memblokir (Reguler / Pemeliharaan)
    // 2. Pengajuan lain yang masih aktif (Menunggu atau Disetujui)
    //    → kedua query memakai ->lockForUpdate()
    // 3. Bila ada irisan → ValidationException (HTTP 422)
    // 4. Bila bebas → Booking::create([... 'status' => 'Menunggu'])
});
```

**Rumus tumpang tindih** — rentang bersifat *half-open*:

```
mulai < selesai_lain  AND  selesai > mulai_lain
```

Jadwal 08:00–10:00 dan 10:00–12:00 **tidak** dianggap bentrok, karena ruangan
bebas tepat pukul 10:00.

### Perbedaan penting dari versi Firebase

| | Firebase (lama) | Laravel (sekarang) |
|---|---|---|
| Pengajuan `Menunggu` | Tidak menahan slot — beberapa pemohon boleh mengajukan waktu sama | **Menahan slot** — satu slot, satu pengajuan aktif |
| Mekanisme | Koleksi `slot_locks` (satu dokumen per lab per hari) | `lockForUpdate()` + indeks `(lab_id, tanggal, status)` |
| Alasan | SDK Flutter tidak bisa `Query` di dalam transaksi | MySQL tidak punya keterbatasan itu |

`slot_locks` **dihapus seluruhnya** — sekitar 600 baris kode beserta model,
service, dan aturan rules-nya tidak diperlukan lagi.

Pengajuan `Ditolak` melepas slotnya kembali.

### Indeks wajib

```sql
INDEX (lab_id, tanggal, status)
```

Bukan sekadar optimasi. Pada InnoDB dengan REPEATABLE READ, `SELECT ... FOR
UPDATE` pada rentang yang terindeks mengambil *gap lock* sehingga baris baru
tidak bisa disisipkan di tengah rentang. Tanpa indeks yang tepat, penguncian
melebar ke seluruh tabel dan celah balapan bisa terbuka kembali.

---

## 7. Status pengerjaan

### ✅ Backend Laravel — selesai dan terverifikasi

Diuji dengan permintaan HTTP nyata terhadap MySQL 8.4.3:

| # | Uji | Hasil |
|---|---|---|
| 1 | Login benar | 200 + token |
| 2 | Login salah | 422 |
| 3 | Tanpa token | 401 |
| 4 | Kalender | 5 lab, 42 jadwal |
| 5 | Ajukan slot kosong | **201**, status `Menunggu` |
| 6 | Ajukan slot sama lagi | **422** + pesan bentrok |
| 7 | Mahasiswa lain, slot bentrok | **422** |
| 8 | Slot bersinggungan tepat di batas | **201** (benar — tidak bentrok) |
| 9 | Durasi > 4 jam | 422 |
| 10 | Di luar jam operasional | 422 |
| 11 | Tanggal lampau | 422 |
| 12 | Mahasiswa mencoba verifikasi | **403** |
| 13 | Tolak tanpa alasan | 422 |
| 14 | Setujui | 200, `Disetujui` |
| 15 | Verifikasi ulang pengajuan final | 403 |

### ✅ Flutter — lapisan data selesai

Model, API service, token storage, dan provider (termasuk polling) sudah
memakai HTTP. Firebase sudah dihapus seluruhnya: dependensi, berkas
`firebase_options.dart`, konfigurasi Gradle `google-services`, dan izin
`google-services.json`.

### ✅ Flutter — lapisan tampilan selesai

Seluruh halaman di `lib/features/*/presentation/` sudah disesuaikan dengan
lapisan data HTTP. `flutter analyze` melaporkan **0 temuan** (error, warning,
maupun info) untuk seluruh berkas di `lib/`.

Yang diubah pada tahap penyelesaian ini:

| Berkas | Perubahan |
|---|---|
| `core/config/app_config.dart` | Ditambahkan kembali `minPasswordLength` dan `appTagline` |
| `core/utils/identity_utils.dart` | Pemetaan email internal dihapus — NIM/NIDN dikirim apa adanya |
| `core/router/app_router.dart`, `routes.dart` | `switch` sesi dibuat ekshaustif; rute `profileMissing` dihapus (tidak ada lagi keadaan "terautentikasi tanpa profil") |
| `features/auth/presentation/login_page.dart` | Memakai pesan galat dari `masuk()`; alur lupa kata sandi menjadi arahan manual karena belum ada endpointnya |
| `features/auth/presentation/register_page.dart` | Memakai pesan galat dari `daftar()` |
| `data/services/auth_api.dart`, `features/auth/providers/auth_providers.dart` | Ditambahkan `daftar()` (POST `/register`) |
| `data/services/lab_api.dart` | **Berkas baru** — CRUD laboratorium (POST/PUT/DELETE `/labs`) |
| `features/calendar/providers/calendar_providers.dart` | `RentangKalender` menyimpan `tanggalTerpilih`; ditambahkan `jadwalHarianProvider`, `pengajuanHarianProvider`, `timelineHarianProvider`, `jadwalBulanProvider`, `semuaLabProvider` |
| `features/calendar/presentation/kalender_ketersediaan_page.dart` | Memakai `petaKeterisianProvider` + `ketersediaanHariProvider(tanggal)` |
| `features/admin/**`, `features/booking/**`, `features/profile/**` | `user.uid` → `user.id`, `Booking.updatedAt` → `reviewedAt`/`createdAt`, `idLab`/`idUser` bertipe `int`, `kalenderApiProvider` → `labApiProvider` |

Backend juga mendapat satu endpoint baru: **`POST /api/register`**
(`AuthController::register` + `RegisterRequest`), karena layar "Daftar akun baru"
sebelumnya memanggil metode yang tidak ada. Peran Kepala Lab tetap tidak dapat
didaftarkan sendiri.

### ⚠️ Konvensi wajib: helper JSON harus statis, bukan extension

Pembacaan respons JSON memakai **helper statis** `Json` di
`lib/core/utils/json_utils.dart`:

```dart
final map = Json.asMap(respons);
final daftar = Json.asMapList(Json.asMap(respons)['data']);
```

**Jangan** menggantinya dengan extension method (`respons.asMap`), dan **jangan**
memakai `extension ... on dynamic`. Keduanya gagal saat runtime.

Sebabnya: extension method di Dart diselesaikan terhadap **tipe statis** penerima.
`ApiClient` mengembalikan `Object?`, tetapi `peta['kunci']` dan elemen
`List<dynamic>` bertipe `dynamic`. Menurut spesifikasi Dart, `dynamic` dianggap
memiliki **semua** nama anggota — sehingga **tidak ada** extension yang pernah
diterapkan padanya (berlaku juga untuk `extension on dynamic`). Panggilan jatuh ke
dynamic dispatch dan gagal dengan:

```
NoSuchMethodError: Class '_Map<String, dynamic>' has no instance getter 'asMap'
```

Argumen `dynamic` yang dilewatkan ke parameter `Object?` pada helper statis,
sebaliknya, hanyalah implicit cast yang selalu sah.

Lint `avoid_dynamic_calls` sudah diaktifkan di `analysis_options.yaml` untuk
menangkap panggilan pada `dynamic` yang lolos dari pemeriksaan statis biasa.

---

## 8. Pemecahan masalah

**`Connection refused` atau `SocketException` di aplikasi**
1. Pastikan server jalan dengan `--host=0.0.0.0`
2. Emulator → `10.0.2.2`, HP fisik → IP LAN laptop
3. HP dan laptop di Wi-Fi yang sama
4. Windows Firewall mengizinkan port 8000

**`CLEARTEXT communication not permitted`**
`android:usesCleartextTraffic="true"` hilang dari `AndroidManifest.xml`.

**`SQLSTATE[HY000] [2002] Connection refused`**
MySQL belum jalan. Nyalakan lewat Laragon.

**`SQLSTATE[42S02] Table not found`**
Jalankan `php artisan migrate:fresh --seed`.

**Pesan validasi muncul sebagai kunci mentah** (`validation.after_or_equal`)
`APP_FALLBACK_LOCALE` disetel ke `id` padahal terjemahan `id` tidak ada.
Biarkan `en`; pesan Indonesia ditambahkan di `Concerns/PesanIndonesia.php`.

**Pengajuan ditolak padahal kalender menunjukkan slot kosong**
Seharusnya tidak terjadi lagi: server dan kalender memakai aturan yang sama
(`Menunggu` dan `Disetujui` sama-sama menahan slot). Bila masih terjadi,
periksa apakah `scopeMenahanSlot()` benar-benar dipakai di
`BookingController` dan `CalendarController`.
