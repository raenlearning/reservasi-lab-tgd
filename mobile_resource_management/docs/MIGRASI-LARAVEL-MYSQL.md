# Migrasi ke Laravel + MySQL — Analisis & Rencana

Dokumen ini menjawab tiga hal: **bagaimana aplikasi bekerja sekarang**, **apakah migrasi penuh ke Laravel + MySQL memungkinkan**, dan **bagaimana melakukannya tanpa kehilangan data**.

Seluruh angka dan klaim di sini diambil dari kode yang ada di repositori ini, bukan dari asumsi.

---

## Daftar isi

1. [Bagian 1 — Alur kerja aplikasi saat ini](#bagian-1--alur-kerja-aplikasi-saat-ini)
2. [Bagian 2 — Arsitektur data & database sekarang](#bagian-2--arsitektur-data--database-sekarang)
3. [Bagian 3 — Komponen yang terlibat dalam migrasi](#bagian-3--komponen-yang-terlibat-dalam-migrasi)
4. [Bagian 4 — Apakah migrasi penuh memungkinkan?](#bagian-4--apakah-migrasi-penuh-memungkinkan)
5. [Bagian 5 — Langkah-langkah utama](#bagian-5--langkah-langkah-utama)
6. [Bagian 6 — Yang perlu dipersiapkan](#bagian-6--yang-perlu-dipersiapkan)
7. [Bagian 7 — Potensi kendala](#bagian-7--potensi-kendala)
8. [Bagian 8 — Rekomendasi agar aman](#bagian-8--rekomendasi-agar-aman)

---

## Bagian 1 — Alur kerja aplikasi saat ini


### Ringkasnya: online-first, dengan baca-saja saat offline

Aplikasi **tidak** dirancang sebagai aplikasi offline. Yang terjadi sekarang:

| Kondisi                    | Perilaku                                           |
| -------------------------- | -------------------------------------------------- |
| **Membaca** saat offline   | ✅ Berjalan dari cache lokal Firestore              |
| **Menulis** saat offline   | ⚠️ Antre di perangkat, dikirim saat online kembali |
| **Transaksi** saat offline | ❌ **Gagal**                                        |

Baris ketiga itu penting. Pengajuan reservasi memakai `runTransaction` untuk memeriksa kunci slot. Transaksi Firestore **memerlukan jaringan** — transaksi tidak pernah dijalankan offline, dan tidak dipersistenkan antar-restart aplikasi. Jadi **mengajukan reservasi tanpa internet akan gagal**, bukan tersimpan untuk nanti.

Perlu ditegaskan: tidak ada satu baris pun kode yang menangani konektivitas. Tidak ada `connectivity_plus`, tidak ada indikator "menunggu sinkronisasi", tidak ada `Settings(persistenceEnabled:)` yang disetel eksplisit. Persistensi cache yang ada murni bawaan SDK Firestore. Artinya bila nanti pindah ke REST API, **seluruh perilaku offline itu hilang** dan tidak ada fallback.


### Arsitektur sekarang

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter (Android) — 62 berkas Dart, ±12.400 baris              │
│                                                                 │
│  features/  (6.839 baris)   Halaman & widget                    │
│  data/      (3.006 baris)   Service, repository, model          │
│  core/      (2.591 baris)   Tema, util, router, widget bersama  │
└───────────────────────────┬─────────────────────────────────────┘
                            │  SDK Firebase (bukan HTTP biasa)
        ┌───────────────────┼───────────────────┬──────────────┐
        ▼                   ▼                   ▼              ▼
   Firebase Auth      Cloud Firestore     Cloud Functions      FCM
   (email/password)   (5 koleksi)         (4 fungsi, ⛔ mati)  (⛔ mati)
```

Tanda ⛔ bukan kesalahan: keduanya butuh paket Blaze, sedangkan proyek berjalan di Spark agar tetap gratis. **Inilah alasan utama migrasi ini menarik** — Laravel bisa mengembalikan notifikasi dan upload berkas tanpa biaya.


### Alur satu pengajuan reservasi

```
Mahasiswa                    Aplikasi Flutter                 Firestore
   │                                │                             │
   │ 1. isi formulir                │                             │
   │───────────────────────────────>│                             │
   │                                │ 2. validasi lokal            │
   │                                │    (jam, durasi, horizon)    │
   │                                │                             │
   │                                │ 3. transaksi:                │
   │                                │    a. baca labs/{id}         │
   │                                │────────────────────────────>│
   │                                │    b. baca slot_locks/...    │
   │                                │────────────────────────────>│
   │                                │    c. slot kosong?           │
   │                                │    d. tulis bookings/{baru}  │
   │                                │────────────────────────────>│
   │ 4. notifikasi status           │                             │
   │<───────────────────────────────│                             │
   │                                │                             │
   │ (Kepala Lab menyetujui)        │                             │
   │                                │ 5. transaksi:                │
   │                                │    a. baca bookings/{id}     │
   │                                │    b. baca slot_locks         │
   │                                │    c. kunci slot + ubah status│
   │                                │────────────────────────────>│
```

Poin penting: **langkah 3 dan 5 adalah transaksi Firestore**, bukan sekadar penulisan. Inilah yang membuat anti-*double booking* bekerja.

### Peran ditentukan di database, bukan di aplikasi

Ini sering terlewat. `firestore.rules` mengevaluasi setiap permintaan dengan membaca dokumen `users/{uid}`:

```javascript
function isAdmin() {
  return profileExists() && profile().jabatan == 'Kepala Lab';
}
```

Jadi otorisasi berjalan **di lapisan database**, deklaratif, dan tidak bisa dilewati klien. Aplikasi Flutter hanya menyembunyikan tombol — bukan penjaga sebenarnya.

---

## Bagian 2 — Arsitektur data & database sekarang

Database: **Cloud Firestore** — NoSQL, dokumen, tanpa skema.

### Lima koleksi

| Koleksi                         | Isi                 | Perkiraan            |
| ------------------------------- | ------------------- | -------------------- |
| `users/{uid}`                   | Profil + peran      | Satu per pengguna    |
| `labs/{labId}`                  | Laboratorium        | 5 dokumen            |
| `lab_schedules/{id}`            | Jadwal acuan        | ±100 per bulan       |
| `bookings/{id}`                 | Pengajuan reservasi | Tumbuh seiring waktu |
| `slot_locks/{id_lab}_{tanggal}` | Indeks keterisian   | 1 per lab per hari   |

### Keputusan desain yang perlu dibawa

**Tanggal & jam disimpan sebagai teks, bukan tipe waktu.**

```
tanggal      : "2026-09-25"     (string)
jam_mulai    : "13:00"          (string)
mulai_menit  : 780              (integer, 13×60)
```

Alasannya: menghindari pergeseran zona waktu, dan `mulai_menit` membuat perbandingan rentang menjadi aritmetika integer yang murah.

**Di MySQL, semua ini tidak lagi diperlukan.** Kolom `DATE` dan `TIME` sudah tepat, bisa di-`ORDER BY`, dan bisa dibandingkan langsung:

```sql
WHERE jam_mulai < :selesai AND :mulai < jam_selesai
```

Kolom `*_menit` bisa dihapus sepenuhnya. Ini penyederhanaan nyata, bukan sekadar kosmetik.


### `slot_locks` — mekanisme yang lahir dari keterbatasan, bukan dari kebutuhan

Ini bagian paling penting untuk dipahami sebelum migrasi.

Firebase SDK Flutter hanya mengizinkan `Transaction.get` pada `DocumentReference`, **bukan `Query`**. Artinya di sisi klien tidak mungkin menjalankan query "apakah ada pengajuan yang bentrok?" di dalam transaksi.

Untuk mengakalinya, seluruh keterisian satu laboratorium pada satu tanggal dipindahkan ke **satu dokumen**, sehingga pemeriksaannya cukup dengan pembacaan dokumen biasa:

```
slot_locks/{id_lab}_{2026-09-25}
  slots: { "16": "s:jadwal001", "20": "b:booking42" }
```

**Di MySQL, akal-akalan ini tidak diperlukan sama sekali.** Database relasional justru dirancang untuk ini:

```php
DB::transaction(function () use ($data) {
    $bentrok = Booking::where('lab_id', $data['lab_id'])
        ->where('tanggal', $data['tanggal'])
        ->where('status', 'Disetujui')
        ->where('jam_mulai', '<', $data['jam_selesai'])
        ->where('jam_selesai', '>', $data['jam_mulai'])
        ->lockForUpdate()          // ← inilah pengganti slot_locks
        ->exists();

    if ($bentrok) {
        throw ValidationException::withMessages([
            'jam_mulai' => 'Slot waktu ini sudah terpakai.',
        ]);
    }

    return Booking::create($data);
});
```

Satu blok `DB::transaction` + `lockForUpdate()` menggantikan seluruh model `LabDayLock`, service `SlotLockService`, koleksi `slot_locks`, dan aturan rules-nya. **Sekitar 600 baris kode hilang dan tidak perlu dipindahkan.**

---

## Bagian 3 — Komponen yang terlibat dalam migrasi

### Yang ditulis ulang (±3.000 baris — 24% kode)

| Komponen sekarang                                                               | Penggantinya di Laravel               |
| ------------------------------------------------------------------------------- | ------------------------------------- |
| `AuthService` (Firebase Auth)                                                   | Laravel Sanctum + controller login    |
| `FirestoreService` (7 query real-time)                                          | Eloquent + REST API                   |
| `FunctionsService` (callable)                                                   | Route API biasa                       |
| `NotificationService` (FCM klien)                                               | FCM HTTP v1 dari server               |
| `SlotLockService`                                                               | `DB::transaction` + `lockForUpdate()` |
| `BookingRepository`, `LabRepository`, `LabScheduleRepository`, `UserRepository` | Eloquent model + controller           |
| `firestore.rules` (5 blok)                                                      | Middleware + Policy + Form Request    |

### Yang dipertahankan (±9.400 baris — 76% kode)

| Komponen                                               | Alasan bertahan                                        |
| ------------------------------------------------------ | ------------------------------------------------------ |
| Seluruh `core/` (tema, util, validasi, router, widget) | Tidak tahu apa pun soal backend                        |
| Seluruh `features/*/presentation/` (25 berkas)         | Hanya memanggil provider                               |
| Seluruh `data/models/`                                 | Berubah dari `toCreateMap()` ke `fromJson()` — mekanis |
| Struktur provider Riverpod                             | Berubah sumber datanya, bukan bentuknya                |

**Inilah alasan migrasi ini layak dipertimbangkan:** batas lapisan `data/services` + `data/repositories` yang saya bangun sejak awal membuat UI tidak perlu disentuh. Kalau UI memanggil Firestore langsung, migrasi ini akan berarti menulis ulang seluruh aplikasi.

### Yang hilang dan harus diganti

**7 query real-time** (`.snapshots()`) dan **9 `StreamProvider`** — kalender, daftar pengajuan, dasbor admin, semuanya memperbarui diri otomatis. Laravel + MySQL tidak punya padanannya. Ini kendala terbesar (lihat [Bagian 7](#bagian-7--potensi-kendala)).

---

## Bagian 4 — Apakah migrasi penuh memungkinkan?

**Ya, sepenuhnya memungkinkan.** Lebih dari itu: untuk kasus ini migrasi justru **menyederhanakan** beberapa hal.

### Yang menjadi lebih sederhana

| Sekarang                                                                | Setelah migrasi                                      |
| ----------------------------------------------------------------------- | ---------------------------------------------------- |
| Login NIM/NIDN diakali lewat email internal `{nim}@trigunadharma.ac.id` | Login langsung dengan `nomor_identitas` + `password` |
| `slot_locks` + service + model + rules (±600 baris)                     | `lockForUpdate()` dalam satu transaksi               |
| `mulai_menit`/`selesai_menit` sebagai kolom bantu                       | Cukup `TIME`                                         |
| Otorisasi tersebar di 5 blok rules                                      | Policy Laravel yang bisa diuji unit                  |
| Notifikasi mati (butuh Blaze)                                           | FCM HTTP v1 dari Laravel — **hidup kembali**         |
| Upload berkas mati (butuh Blaze)                                        | `Storage::disk()` — **hidup kembali**                |
| Backup/restore tidak tersedia gratis                                    | `mysqldump` — gratis                                 |

### Yang menjadi lebih sulit

| Sekarang                          | Setelah migrasi                                                    |
| --------------------------------- | ------------------------------------------------------------------ |
| Real-time otomatis dari Firestore | Harus dibangun: polling, SSE, atau WebSocket                       |
| Cache offline gratis              | Harus dibangun: SQLite lokal + sinkronisasi                        |
| Tanpa server untuk dikelola       | Harus menjalankan & merawat VPS (uptime, backup, patch)            |
| Otorisasi di lapisan database     | Otorisasi di lapisan aplikasi — bug di controller = kebocoran data |

### Penilaian jujur

Untuk **konteks tugas kuliah**, migrasi ini masuk akal dan sebaiknya dilakukan — apalagi diagram arsitektur yang Anda lampirkan memang menargetkan Flutter + Laravel + MySQL. Repositori ini kebetulan sudah punya batas lapisan yang membuat migrasinya relatif murah.

Untuk **konteks produksi kampus**, pertimbangkan bahwa Anda menukar *managed service* dengan *self-hosted*. Firestore tidak perlu dirawat; MySQL di VPS perlu.

**Kabar baiknya:** proyek ini masih sangat muda. Data yang ada kemungkinan besar hanya beberapa akun uji dan beberapa laboratorium. **Inilah waktu paling murah untuk bermigrasi** — hampir tidak ada data yang berisiko hilang.

---

## Bagian 5 — Langkah-langkah utama

### Fase 0 — Bekukan & cadangkan (sebelum menyentuh apa pun)

1. Ekspor seluruh Firestore: Firebase Console → Firestore → *Import/Export*.  
   (Catatan: ekspor terjadwal butuh billing. Untuk proyek kecil, ekspor manual ke Cloud Storage atau salin data lewat skrip sudah cukup.)
2. Simpan `firestore.rules`, `firestore.indexes.json`, dan `functions/` di repositori terpisah.
3. Tandai repositori Flutter dengan tag Git: `git tag pra-migrasi`.


### Fase 1 — Rancang skema MySQL

Skema setara, sudah dinormalisasi:

```sql
users
  id                BIGINT UNSIGNED PK AUTO_INCREMENT
  nomor_identitas   VARCHAR(20)  UNIQUE NOT NULL     -- NIM / NIDN
  nama              VARCHAR(100) NOT NULL
  email             VARCHAR(150) UNIQUE NULL
  password          VARCHAR(255) NOT NULL            -- bcrypt
  jabatan           ENUM('Mahasiswa','Dosen','Kepala Lab') NOT NULL
  fcm_token         VARCHAR(255) NULL
  is_active         BOOLEAN NOT NULL DEFAULT TRUE
  timestamps

labs
  id                BIGINT UNSIGNED PK
  nama_lab          VARCHAR(100) UNIQUE NOT NULL
  kapasitas         SMALLINT UNSIGNED NOT NULL
  lokasi            VARCHAR(150) NULL
  fasilitas         JSON NULL
  is_active         BOOLEAN NOT NULL DEFAULT TRUE
  timestamps

lab_schedules
  id                BIGINT UNSIGNED PK
  lab_id            BIGINT UNSIGNED FK -> labs.id  ON DELETE RESTRICT
  mata_kuliah       VARCHAR(100) NOT NULL
  nama_dosen        VARCHAR(100) NULL
  tanggal           DATE NOT NULL
  jam_mulai         TIME NOT NULL
  jam_selesai       TIME NOT NULL
  tipe              ENUM('Reguler','Pengganti','Pemeliharaan') NOT NULL
  semester          VARCHAR(20) NULL
  catatan           TEXT NULL
  created_by        BIGINT UNSIGNED FK -> users.id NULL
  timestamps
  INDEX (lab_id, tanggal)

bookings
  id                BIGINT UNSIGNED PK
  user_id           BIGINT UNSIGNED FK -> users.id  ON DELETE RESTRICT
  lab_id            BIGINT UNSIGNED FK -> labs.id   ON DELETE RESTRICT
  mata_kuliah       VARCHAR(100) NOT NULL
  tanggal           DATE NOT NULL
  jam_mulai         TIME NOT NULL
  jam_selesai       TIME NOT NULL
  status            ENUM('Menunggu','Disetujui','Ditolak') NOT NULL DEFAULT 'Menunggu'
  catatan           TEXT NULL
  alasan_penolakan  TEXT NULL
  reviewed_by       BIGINT UNSIGNED FK -> users.id NULL
  reviewed_at       TIMESTAMP NULL
  timestamps
  INDEX (user_id, created_at)
  INDEX (status, tanggal)
  INDEX (lab_id, tanggal, status)
```

**Yang hilang dari skema lama:** `slot_locks` (tidak diperlukan), `mulai_menit`/`selesai_menit` (digantikan `TIME`), `nama_pemohon`/`nomor_identitas_pemohon` (denormalisasi yang tidak lagi perlu — cukup `JOIN`).

### Fase 2 — Bangun Laravel

```bash
composer create-project laravel/laravel mrm-api
cd mrm-api
composer require laravel/sanctum
```

Konfigurasi `.env`:

```env
APP_TIMEZONE=Asia/Jakarta
DB_CONNECTION=mysql
DB_DATABASE=mrm_triguna
DB_USERNAME=...
DB_PASSWORD=...
```

> `APP_TIMEZONE` wajib disetel. Laravel default UTC, sedangkan jadwal kampus adalah WIB. Tanpa ini, "Senin 08:00" bisa bergeser.

Buat migration, model, relasi, lalu Policy:

```bash
php artisan make:model Lab -m
php artisan make:model LabSchedule -m
php artisan make:model Booking -m
php artisan make:policy BookingPolicy
```


### Fase 3 — Pindahkan otorisasi

Terjemahkan tiap blok `firestore.rules` menjadi Policy. Contoh:

```php
// app/Policies/BookingPolicy.php
public function create(User $user): bool
{
    return $user->is_active;
}

public function review(User $user, Booking $booking): bool
{
    return $user->jabatan === 'Kepala Lab'
        && $booking->status === 'Menunggu';
}

public function delete(User $user, Booking $booking): bool
{
    return $booking->user_id === $user->id
        && $booking->status === 'Menunggu';
}
```

Lalu validasi bentuk di Form Request — pengganti `allow create: if ... && jam_mulai is string && ...`:

```php
// app/Http/Requests/StoreBookingRequest.php
public function rules(): array
{
    return [
        'lab_id'      => ['required', 'exists:labs,id'],
        'mata_kuliah' => ['required', 'string', 'min:3', 'max:100'],
        'tanggal'     => ['required', 'date_format:Y-m-d', 'after_or_equal:today',
                          'before_or_equal:' . now()->addDays(60)->format('Y-m-d')],
        'jam_mulai'   => ['required', 'date_format:H:i'],
        'jam_selesai' => ['required', 'date_format:H:i', 'after:jam_mulai'],
    ];
}
```

### Fase 4 — Migrasikan data

Skrip sekali-jalan: baca ekspor Firestore → transformasi → `insert` ke MySQL.

Hal yang harus diperhatikan saat transformasi:

| Dari Firestore                            | Ke MySQL                                          |
| ----------------------------------------- | ------------------------------------------------- |
| `jabatan: "Kepala Lab"`                   | sama                                              |
| `tanggal: "2026-09-25"`                   | `DATE '2026-09-25'`                               |
| `jam_mulai: "13:00"` + `mulai_menit: 780` | `TIME '13:00:00'` (buang `mulai_menit`)           |
| `id_user: "<uid Firebase>"`               | perlu peta `uid → users.id`                       |
| `id_lab: "<docId>"`                       | perlu peta `docId → labs.id`                      |
| `fasilitas: ["40 PC","AC"]`               | `JSON '["40 PC","AC"]'`                           |
| `created_at: <Timestamp>`                 | `DATETIME`                                        |
| `slot_locks/*`                            | **dibuang** — akan dibangun ulang oleh constraint |

Petakan UID Firebase ke `users.id` lebih dulu, simpan di tabel sementara, lalu pakai untuk `bookings.user_id` dan `lab_schedules.created_by`.

### Fase 5 — Ubah sisi Flutter

Tambahkan sakelar backend, seperti pola `useCloudFunctionsForBooking` yang sudah ada:

```dart
enum BackendAktif { firestore, laravel }

class AppConfig {
  static const BackendAktif backend = BackendAktif.laravel;
}
```

Lalu di provider, pilih implementasi repository sesuai sakelar itu. Dengan begitu **kedua backend bisa hidup berdampingan** selama masa transisi — inilah kunci migrasi yang aman.

Ganti query real-time dengan salah satu strategi di [Bagian 7](#bagian-7--potensi-kendala).

### Fase 6 — Uji berdampingan, lalu potong

1. Jalankan kedua backend dengan data yang sama
2. Bandingkan hasil untuk 10 skenario uji terima (lihat `CHECKLIST-SETUP.md` A8)
3. Khusus uji bentrok: pastikan dua pengajuan bersamaan hanya lolos satu
4. Setelah yakin, ubah sakelar ke `laravel`, rilis
5. Pertahankan Firebase hidup minimal 2 minggu sebagai jalan mundur

---

## Bagian 6 — Yang perlu dipersiapkan

### Perangkat lunak

| Kebutuhan    | Versi | Catatan                           |
| ------------ | ----- | --------------------------------- |
| PHP          | 8.2+  | Laravel 11 memerlukan 8.2 minimum |
| Composer     | 2.x   |                                   |
| MySQL        | 8.0+  | atau MariaDB 10.6+                |
| Laravel      | 11.x  |                                   |
| MySQL client | —     | untuk `mysqldump`                 |

Untuk lokal: **Laragon** atau **XAMPP** sudah cukup. Untuk produksi: VPS dengan Nginx + PHP-FPM.

### Keputusan yang harus diambil lebih dulu

Tiga hal ini menentukan bentuk implementasi. Sebaiknya diputuskan **sebelum** menulis kode:

1. **Real-time:** polling, SSE, atau WebSocket (Laravel Reverb)?
2. **Offline:** perlu atau tidak? Kalau perlu, tambahkan SQLite lokal — ini pekerjaan besar tersendiri.
3. **Autentikasi:** Sanctum (token, lebih sederhana) atau JWT (`tymon/jwt-auth`, lebih umum di proyek kampus)?

### Data & berkas

- Ekspor Firestore (kalau ada data)
- Daftar akun pengguna + perannya
- Daftar laboratorium dan jadwal yang berlaku
- Berkas jadwal yang pernah diunggah (kalau ada)

### Hal yang **tidak bisa** dipersiapkan

**Kata sandi pengguna tidak dapat dimigrasikan.** Firebase Authentication menyimpan hash kata sandi di infrastruktur Google dan **tidak menyediakannya untuk diekspor** — ini disengaja, bukan keterbatasan. Saat pindah ke Laravel:

- Setiap pengguna **harus mengatur ulang kata sandi**
- Atau Kepala Lab membuatkan kata sandi sementara
- Atau (hanya untuk tugas) semua akun diberi kata sandi awal yang sama dan wajib diganti

Rencanakan komunikasi ini ke pengguna sebelum hari-H.

---

## Bagian 7 — Potensi kendala

Diurutkan dari yang paling berisiko.

### 1. Kehilangan real-time — risiko tinggi

**Masalah:** 7 query `.snapshots()` dan 9 `StreamProvider` memberi pembaruan otomatis. Kalender ketersediaan, daftar pengajuan, dan dasbor admin semuanya bergantung padanya. Laravel + MySQL tidak punya padanannya.

**Pilihan:**

| Pendekatan         | Kompleksitas | Keterlambatan | Catatan                                               |
| ------------------ | ------------ | ------------- | ----------------------------------------------------- |
| **Polling**        | Rendah       | 5–30 detik    | `Timer.periodic` memanggil GET. Paling cepat dibangun |
| **SSE**            | Sedang       | < 1 detik     | Satu arah, cukup untuk pembaruan data                 |
| **Laravel Reverb** | Tinggi       | < 1 detik     | WebSocket sungguhan, dua arah, perlu server tambahan  |

**Rekomendasi:** mulai dari polling 15 detik untuk kalender, lalu naikkan ke Reverb hanya bila benar-benar diperlukan. Untuk aplikasi kampus dengan puluhan pengguna, polling sudah memadai dan jauh lebih sederhana untuk dipertanggungjawabkan dalam sidang.

### 2. Kehilangan cache offline — risiko sedang

**Masalah:** Firestore memberi cache gratis. REST API tidak. Kalau jaringan putus, aplikasi menampilkan galat, bukan data lama.

**Rekomendasi:** untuk tugas, terima saja — tampilkan pesan "tidak dapat terhubung" yang jelas. Kalau offline benar-benar diperlukan, tambahkan `sqflite`/`drift` sebagai cache baca, dan **jangan** antre penulisan offline (menyebabkan konflik yang sulit dijelaskan).

### 3. Otorisasi berpindah lapisan — risiko sedang, dampak besar

**Masalah:** sekarang aturan akses ditegakkan di database dan tidak bisa dilewati. Setelah migrasi, ia ada di kode aplikasi. Satu controller yang lupa memanggil `$this->authorize()` = kebocoran data.

**Rekomendasi:**

- Aktifkan `Model::preventLazyLoading()` di `AppServiceProvider` untuk menangkap masalah N+1
- Pakai **Form Request** untuk setiap endpoint tulis
- Pakai **Policy** untuk setiap operasi, jangan pernah memeriksa peran langsung di controller
- Tambahkan test otorisasi: untuk setiap endpoint, uji bahwa peran yang salah mendapat 403

### 4. Zona waktu — risiko sedang, mudah dicegah

**Masalah:** Laravel default UTC. Jadwal kampus adalah WIB (UTC+7). Tanpa penanganan, jadwal 08:00 bisa tampil sebagai 01:00.

**Rekomendasi:** setel `APP_TIMEZONE=Asia/Jakarta` di `.env` **sebelum** menulis data pertama. Sekalian: gunakan kolom `DATE` + `TIME` (bukan `TIMESTAMP`) untuk jadwal, karena jadwal adalah waktu dinding, bukan titik waktu absolut.

### 5. Logika bentrok berubah bentuk — risiko sedang

**Masalah:** `lockForUpdate()` bergantung pada isolasi transaksi InnoDB. Pada `REPEATABLE READ` (default), query rentang yang terindeks akan mengambil *gap lock* sehingga mencegah baris baru disisipkan di rentang itu. Perilaku ini benar tetapi halus — dan mudah rusak bila indeksnya salah.

**Rekomendasi:** pastikan ada `INDEX (lab_id, tanggal, status)`. Sebagai jaring pengaman tambahan, pertimbangkan tabel `booking_slots (lab_id, tanggal, slot_index)` dengan `UNIQUE(lab_id, tanggal, slot_index)` — pelanggaran constraint akan menggagalkan transaksi secara otomatis, tanpa bergantung pada semantik penguncian.

### 6. Kata sandi tidak dapat dimigrasikan — risiko rendah, dampak pengguna

Sudah dibahas di [Bagian 6](#bagian-6--yang-perlu-dipersiapkan). Rencanakan reset massal.

### 7. Operasional server — risiko rendah untuk tugas, tinggi untuk produksi

Anda kini memiliki server. Perlu: backup terjadwal, pembaruan keamanan, pemantauan, dan sertifikat TLS. Firestore tidak menuntut satu pun dari itu.

---

## Bagian 8 — Rekomendasi agar aman

### Prinsip utama: jangan potong sekaligus

Bangun Laravel **berdampingan** dengan Firebase, jangan menggantikannya. Sakelar `AppConfig.backend` memungkinkan kedua implementasi hidup bersama, sehingga:

- Aplikasi tetap berfungsi selama pengembangan Laravel
- Anda bisa membandingkan hasil kedua backend pada data yang sama
- Jalan mundur selalu tersedia

### Urutan yang disarankan

1. **Bekukan & cadangkan** — tag Git, ekspor Firestore, arsipkan rules
2. **Rancang skema MySQL** dan tinjau bersama dosen pembimbing sebelum menulis kode
3. **Bangun Laravel sampai bisa login + satu endpoint** (`GET /api/labs`), uji dengan Postman
4. **Pindahkan otorisasi** ke Policy, lengkapi dengan test 403
5. **Implementasi endpoint pengajuan** dengan `lockForUpdate()`, uji bentrok secara serius
6. **Skrip migrasi data** — uji di database kosong dulu, minimal dua kali
7. **Ubah Flutter** dengan sakelar backend; uji berdampingan
8. **Potong** setelah 10 skenario uji terima lolos di kedua backend
9. **Pertahankan Firebase** minimal 2 minggu

### Daftar periksa sebelum potong

- [ ] Seluruh 10 skenario uji terima lolos di backend Laravel
- [ ] Uji bentrok: dua pengajuan bersamaan pada slot sama → hanya satu lolos
- [ ] Uji otorisasi: mahasiswa tidak bisa menyetujui pengajuan orang lain (403)
- [ ] Uji otorisasi: mahasiswa tidak bisa mengubah jadwal lab (403)
- [ ] Jumlah baris di MySQL sama dengan jumlah dokumen di Firestore (per koleksi)
- [ ] Tanggal & jam di MySQL identik dengan yang di Firestore (periksa 10 sampel acak)
- [ ] Relasi utuh: tidak ada `bookings` dengan `user_id` yang tidak ada di `users`
- [ ] `APP_TIMEZONE=Asia/Jakarta` terpasang
- [ ] Backup otomatis MySQL aktif
- [ ] Kata sandi semua akun sudah direset
- [ ] Firebase masih hidup sebagai jalan mundur

### Jangan lakukan

- **Jangan** menjalankan migrasi data ke database produksi sebelum diuji di database kosong
- **Jangan** menghapus Firebase sebelum masa paralel selesai
- **Jangan** memindahkan `slot_locks` ke MySQL — mekanisme itu tidak diperlukan lagi
- **Jangan** mempertahankan `mulai_menit`/`selesai_menit` — `TIME` sudah cukup
- **Jangan** menyimpan tanggal sebagai `VARCHAR` hanya karena Firestore begitu

---

## Penutup

Migrasi penuh ke Laravel + MySQL **memungkinkan, dan untuk kasus ini justru menyederhanakan** beberapa bagian: `slot_locks` hilang, `mulai_menit` hilang, akal-akalan email internal hilang, dan notifikasi serta upload berkas hidup kembali tanpa biaya.

Yang Anda korbankan adalah **real-time otomatis** dan **cache offline gratis** — keduanya harus dibangun sendiri.

Karena proyek masih sangat muda dan datanya masih sedikit, **inilah waktu paling murah untuk bermigrasi**. Risiko kehilangan data mendekati nol asalkan Fase 0 dijalankan dan kedua backend dijalankan berdampingan sampai uji terima lolos.

---

## Rujukan

| Dokumen                                    | Isi                                                          |
| ------------------------------------------ | ------------------------------------------------------------ |
| [`ARSITEKTUR.md`](ARSITEKTUR.md)           | Arsitektur sekarang, penjelasan lengkap mekanisme kunci slot |
| [`BIAYA-DAN-KUOTA.md`](BIAYA-DAN-KUOTA.md) | Batasan paket gratis Firebase yang menjadi latar migrasi     |
| [`CHECKLIST-SETUP.md`](CHECKLIST-SETUP.md) | 10 skenario uji terima yang harus lolos di kedua backend     |
| [`../README.md`](../README.md)             | Skema data Firestore, aturan validasi, pemecahan masalah     |
