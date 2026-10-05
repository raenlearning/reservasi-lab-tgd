# Mobile Resource Management — STMIK Triguna Dharma

Aplikasi mobile (Flutter + Firebase) untuk mendigitalisasi **pengajuan dan reservasi kelas pengganti** di laboratorium komputer STMIK Triguna Dharma.

Saat ini prosedur pengajuan masih konvensional: dosen atau perwakilan mahasiswa harus mendatangi ruangan Kepala Laboratorium untuk mengecek ketersediaan ruangan dan meminta persetujuan. Aplikasi ini menggantikannya dengan alur mandiri lewat smartphone, lengkap dengan validasi bentrok jadwal otomatis dan notifikasi dua arah.

---

## Daftar isi

1. [Fitur](#fitur)
2. [Arsitektur singkat](#arsitektur-singkat)
3. [Prasyarat](#prasyarat)
4. [Langkah setup](#langkah-setup)
5. [Menyiapkan akun Kepala Laboratorium](#menyiapkan-akun-kepala-laboratorium)
6. [Menjalankan aplikasi](#menjalankan-aplikasi)
7. [Struktur project](#struktur-project)
8. [Skema data Firestore](#skema-data-firestore)
9. [Aturan validasi](#aturan-validasi)
10. [Status pengerjaan](#status-pengerjaan)
11. [Pemecahan masalah](#pemecahan-masalah)

**Dokumen lain:** [`docs/CHECKLIST-SETUP.md`](docs/CHECKLIST-SETUP.md) (checklist setup & urutan implementasi) · [`docs/BIAYA-DAN-KUOTA.md`](docs/BIAYA-DAN-KUOTA.md) (jalur 100% gratis & kuota) · [`docs/ARSITEKTUR.md`](docs/ARSITEKTUR.md) (penjelasan desain) · [`docs/MIGRASI-LARAVEL-MYSQL.md`](docs/MIGRASI-LARAVEL-MYSQL.md) (rencana migrasi ke Laravel + MySQL)

---

## Fitur

| # | Fitur | Aktor | Status |
|---|-------|-------|--------|
| 1 | Registrasi & login memakai NIM/NIDN | Mahasiswa, Dosen | ✅ Selesai |
| 2 | Kalender ketersediaan laboratorium real-time | Semua | ✅ Selesai |
| 3 | Input / ubah / hapus jadwal acuan lab | Kepala Lab | ✅ Selesai |
| 4 | Formulir pengajuan reservasi kelas pengganti | Mahasiswa, Dosen | ✅ Selesai |
| 5 | Validasi bentrok otomatis (concurrency control) | Sistem | ✅ Selesai |
| 6 | Verifikasi / persetujuan jarak jauh | Kepala Lab | ✅ Selesai |
| 7 | Push notification dua arah | Semua | ✅ Selesai |
| 8 | Pembatalan pengajuan oleh pemohon | Mahasiswa, Dosen | ✅ Selesai |
| 9 | Kelola laboratorium (CRUD) | Kepala Lab | ✅ Selesai |

**Non-fungsional yang sudah diterapkan**

- **Mobile accessibility** — Android, nyaman dipakai satu tangan, area sentuh minimum 48dp.
- **Performance** — data per bulan dibaca sekali lalu dipakai ulang lewat provider; nama laboratorium di-cache sehingga daftar pengajuan tidak memicu pembacaan tambahan.
- **Usability & clean design** — satu aksen warna, warna lain khusus menandai status; tema terang & gelap.
- **Keamanan** — peran ditentukan server-side; klien tidak bisa memilih jabatan sendiri.

---

## Arsitektur singkat

```
Flutter (Android)
  │
  ├── Firebase Authentication     → login NIM/NIDN (dipetakan ke email internal)
  ├── Cloud Firestore             → users, labs, lab_schedules, bookings
  ├── Cloud Functions (callable)  → submitBooking, reviewBooking
  ├── Cloud Functions (trigger)   → onBookingCreated, onBookingReviewed
  └── Firebase Cloud Messaging    → notifikasi ke Kepala Lab & pemohon
```

Pemisahan lapisan:

```
UI (features/…)  →  Provider (Riverpod)  →  Repository  →  Service  →  Firebase
```

UI tidak pernah menyentuh Firestore langsung. Repository memetakan dokumen ke model dan mengubah kesalahan Firebase menjadi `AppException` berbahasa Indonesia.

Detail lengkap: [`docs/ARSITEKTUR.md`](docs/ARSITEKTUR.md).

---

## Prasyarat

| Perangkat | Versi yang dipakai | Catatan |
|-----------|-------------------|---------|
| Flutter | 3.44.3 (stable) | `flutter --version` |
| Dart | 3.12.2 | ikut Flutter |
| Android SDK | API 36 | `flutter doctor` |
| JDK | 17 (bawaan Android Studio) | |
| Node.js | 22 | untuk Cloud Functions & skrip seed |
| Firebase CLI | terbaru | `npm i -g firebase-tools` |
| FlutterFire CLI | terbaru | `dart pub global activate flutterfire_cli` |

---

## Langkah setup

> **Sudah pernah setup sebagian?** Lihat
> [`docs/CHECKLIST-SETUP.md`](docs/CHECKLIST-SETUP.md) — berisi status yang sudah
> terverifikasi, sisa langkah, dan urutan pengerjaan yang disarankan.

### 1. Pasang dependensi

```bash
flutter pub get
```

### 2. Hubungkan ke project Firebase Anda

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<PROJECT_ID_FIREBASE_ANDA>
```

Perintah ini akan:

- menimpa `lib/firebase_options.dart` (sebelumnya berisi placeholder),
- mengunduh `android/app/google-services.json`,
- menerapkan plugin Gradle `google-services`.

> **Selama langkah ini belum dijalankan**, aplikasi tetap bisa dibuka tetapi menampilkan layar *"Konfigurasi Firebase diperlukan"* berisi panduan — bukan layar galat.

### 3. Aktifkan layanan Firebase

Di [Firebase Console](https://console.firebase.google.com):

| Layanan | Yang harus dilakukan |
|---------|---------------------|
| **Authentication** | Aktifkan provider **Email/Password** |
| **Cloud Firestore** | Buat database, mulai dengan **mode production** |
| **Cloud Messaging** | Aktif otomatis; tidak ada konfigurasi tambahan |
| **Cloud Functions** | Perlu paket **Blaze** (pay-as-you-go) — lihat catatan di bawah |

> **Ingin 100% gratis?** Cloud Functions **tidak tersedia** di paket Spark, sehingga
> validasi bentrok di server tidak aktif. Aplikasi tetap berjalan penuh lewat jalur
> klien, dengan satu keterbatasan yang perlu Anda ketahui. Selengkapnya di
> [`docs/BIAYA-DAN-KUOTA.md`](docs/BIAYA-DAN-KUOTA.md).

### 4. Deploy Security Rules, index, dan Cloud Functions

```bash
firebase login
firebase use <PROJECT_ID_ANDA>

firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

Setelah functions berhasil di-deploy, **aktifkan jalur produksi** di `lib/core/config/app_config.dart`:

```dart
static const bool useCloudFunctionsForBooking = true;
```

> **Penting.** Jalur langsung dari klien (`false`) **tidak bebas race condition**: Firebase SDK Flutter hanya mengizinkan `Transaction.get` pada `DocumentReference`, bukan `Query`. Artinya pemeriksaan bentrok di klien tidak bisa dijalankan di dalam transaksi. Cloud Function `submitBooking` memakai Admin SDK yang mendukung query di dalam transaksi, sehingga *double booking* benar-benar tercegah. Penjelasan lengkap ada di [`docs/ARSITEKTUR.md`](docs/ARSITEKTUR.md).

### 5. Isi data awal laboratorium

```bash
cd tools/seed
npm install
# unduh service account key dari Firebase Console ->
#   Project settings -> Service accounts -> Generate new private key
# simpan sebagai tools/seed/serviceAccountKey.json
node seed.mjs
```

Skrip ini mengisi 5 laboratorium dan contoh jadwal praktikum untuk 21 hari ke depan, sehingga kalender ketersediaan langsung dapat didemokan.

Opsi tambahan:

```bash
node seed.mjs --reset       # hapus data lama lebih dulu
node seed.mjs --hari=60     # rentang jadwal contoh lebih panjang
```

> Alternatif tanpa skrip: tambahkan dokumen pada koleksi `labs` secara manual melalui Firebase Console. Field yang wajib ada: `nama_lab` (string), `kapasitas` (number), `is_active` (boolean).

---

## Menyiapkan akun Kepala Laboratorium

Akun Kepala Lab **tidak dapat** dibuat lewat halaman registrasi aplikasi — ini
disengaja agar tidak terjadi eskalasi hak akses. Registrasi hanya menerima
`Mahasiswa` dan `Dosen`, dan Security Rules memaksanya:

```javascript
allow create: if ... && request.resource.data.jabatan in ['Mahasiswa', 'Dosen'];
```

> ### ⚠️ Nilainya harus **persis** `Kepala Lab`
>
> Security Rules membandingkan string secara persis:
> `profile().jabatan == 'Kepala Lab'`.
>
> Menulis `Admin`, `admin`, `Kepala Laboratorium`, atau `kalab` akan membuat
> pengguna tersebut **bukan** Kepala Lab di mata rules — setiap tindakan
> verifikasi dan pengelolaan jadwal akan ditolak dengan `permission-denied`,
> tanpa pesan yang menjelaskan sebabnya.
>
> Sejak versi ini, aplikasi juga bersikap tegas: nilai yang tidak dikenal
> diperlakukan sebagai Mahasiswa, dan layar **Profil** menampilkan peringatan
> berisi nilai mentahnya sehingga salah tulis langsung terlihat.

### Cara 1 — Lewat Firebase Console (tanpa berkas rahasia)

**Langkah 1.** Firebase Console → **Authentication** → tab *Users* → **Add user**.

| Kolom | Isi |
|-------|-----|
| Email | `<NIDN>@trigunadharma.ac.id` — mis. `9999000001@trigunadharma.ac.id` |
| Password | Minimal 8 karakter |

Email harus memakai domain internal tersebut, karena login memakai NIDN yang
dipetakan ke email oleh `IdentityUtils.toInternalEmail`.

**Langkah 2.** Salin **UID** pengguna yang baru dibuat.

**Langkah 3.** Firebase Console → **Firestore Database** → koleksi `users` →
**Add document** → isi **Document ID** dengan **UID tadi** (bukan Auto-ID).

Field yang wajib ada:

| Field | Tipe | Nilai |
|-------|------|-------|
| `uid` | string | UID yang sama |
| `nomor_identitas` | string | NIDN, mis. `9999000001` |
| `nama` | string | Nama lengkap |
| `email` | string | Email internal tadi |
| `jabatan` | string | **`Kepala Lab`** |
| `is_active` | boolean | `true` |

Field opsional: `fcm_token` (string, boleh dikosongkan), `created_at` dan
`updated_at` (timestamp).

**Langkah 4.** Masuk ke aplikasi memakai **NIDN** `9999000001` — bukan email.

> **Document ID harus sama dengan UID.** Aplikasi mencari profil lewat
> `users/{uid}`. Kalau ID-nya berbeda, Anda akan diarahkan ke layar
> *"Profil belum lengkap"* — layar itu menampilkan UID yang benar supaya bisa
> disalin.

### Cara 2 — Lewat skrip (butuh service account key)

```bash
cd tools/seed
node promote-admin.mjs \
  --identitas=9999000001 \
  --nama="Kepala Lab STMIK TD" \
  --password=KataSandiKuat123
```

Skrip akan membuat akun Auth (bila belum ada) sekaligus dokumen `users` dengan
`jabatan: "Kepala Lab"`. Perlu `tools/seed/serviceAccountKey.json` — lihat
[langkah 5 setup](#5-isi-data-awal-laboratorium).

### Mengapa login memakai NIM/NIDN, bukan email?

Firebase Authentication hanya menerima email sebagai identifier, sedangkan dokumen tugas mensyaratkan login memakai NIM/NIDN dan tabel `users` tidak punya kolom email. Solusinya: NIM/NIDN dipetakan ke email internal pada domain kampus.

```
NIM 2021010042  →  2021010042@trigunadharma.ac.id
```

Domain dapat diubah di `lib/core/config/app_config.dart` → `internalEmailDomain`.

**Konsekuensi:** fitur "Lupa kata sandi" mengirim tautan ke email internal tersebut, yang hanya berguna bila domain kampus meneruskan email. Untuk lingkungan kampus, cara yang lebih praktis adalah reset manual oleh Kepala Lab lewat Firebase Console.

---

## Menjalankan aplikasi

```bash
flutter run
```

Untuk perangkat fisik:

```bash
flutter devices
flutter run -d <DEVICE_ID>
```

Build APK:

```bash
flutter build apk --debug     # APK debug
flutter build apk --release   # APK rilis
```

---

## Struktur project

```
mobile_resource_management/
├── android/                        Konfigurasi platform Android
├── functions/                      Cloud Functions (TypeScript)
│   └── src/
│       ├── index.ts                Titik masuk & konfigurasi region
│       ├── bookings.ts             submitBooking, reviewBooking
│       ├── notifications.ts        Trigger FCM dua arah
│       ├── constants.ts            Enum & nama field (sinkron dgn Flutter)
│       └── utils.ts                Utilitas waktu & deteksi bentrok
├── lib/
│   ├── main.dart                   Bootstrap: locale, Firebase, runApp
│   ├── app.dart                    MaterialApp.router + tema + locale
│   ├── firebase_options.dart       Placeholder — ditimpa flutterfire
│   ├── core/
│   │   ├── config/                 AppConfig, bootstrap Firebase
│   │   ├── constants/              Nama koleksi & field Firestore
│   │   ├── errors/                 AppException + pemetaan kesalahan
│   │   ├── router/                 Routes + GoRouter dengan guard
│   │   ├── theme/                  Warna, tipografi, komponen
│   │   ├── utils/                  Tanggal, validasi, NIM/NIDN
│   │   └── widgets/                Widget bersama (tombol, field, state)
│   ├── data/
│   │   ├── models/                 AppUser, Lab, Booking, LabSchedule, …
│   │   ├── providers/              Provider service & repository
│   │   ├── repositories/           Akses data + validasi
│   │   └── services/               Auth, Firestore, Functions, FCM
│   └── features/
│       ├── auth/                   Login, registrasi, splash
│       ├── home/                   Beranda Mahasiswa/Dosen
│       ├── calendar/               Kalender ketersediaan (fitur inti)
│       ├── booking/                Formulir pengajuan, detail, daftar & kartu
│       ├── admin/                  Dasbor, jadwal, verifikasi, kelola lab
│       ├── profile/                Profil & pengaturan
│       ├── notifications/          Jembatan FCM + notifikasi lokal
│       └── shell/                  Navigasi bawah
├── tools/seed/                     Skrip seed data & pembuatan admin
├── firestore.rules                 Security Rules Firestore
├── firestore.indexes.json          Composite index
├── storage.rules                   Security Rules Storage
└── firebase.json                   Konfigurasi Firebase CLI
```

### Berkas yang paling sering dibuka saat pengembangan

| Berkas | Isi |
|--------|-----|
| `lib/core/config/app_config.dart` | Semua konstanta yang bisa berubah (jam operasional, horizon hari, region functions, `useCloudFunctionsForBooking`) |
| `lib/core/router/app_router.dart` | Guard sesi & peran, definisi seluruh rute |
| `lib/features/calendar/providers/calendar_providers.dart` | Seluruh turunan kalender: peta keterisian, slot kosong, ketersediaan per lab |
| `lib/data/repositories/booking_repository.dart` | Aturan bentrok sisi klien + facade `submit()` / `review()` |
| `functions/src/bookings.ts` | Validasi bentrok otoritatif (concurrency control) |
| `firestore.rules` | Batas hak akses setiap koleksi |

---

## Skema data Firestore

Rancangan tabel MySQL pada dokumen tugas dipetakan ke Cloud Firestore. Perbedaan penting:

| MySQL | Firestore | Alasan |
|-------|-----------|--------|
| `INT AUTO_INCREMENT PRIMARY KEY` | Document ID (auto) | Firestore memakai ID dokumen |
| `FOREIGN KEY … ON DELETE CASCADE` | Tidak ada | Digantikan Security Rules + Cloud Functions |
| `DATE` | `String` `yyyy-MM-dd` | Bebas masalah zona waktu, tetap bisa di-query rentang |
| `TIME` | `String` `HH:mm` + `int` `*_menit` | String untuk keterbacaan, integer agar deteksi bentrok murah |
| `ENUM('…')` | `String` | Divalidasi di rules & model |
| `password VARCHAR(255)` | — | Dikelola Firebase Authentication, tidak disimpan di database |

### `users/{uid}`

```jsonc
{
  "uid": "…",                       // = Firebase Auth UID = document id
  "nomor_identitas": "2021010042",  // NIM atau NIDN (unik)
  "nama": "Budi Santoso",
  "email": "2021010042@trigunadharma.ac.id",
  "jabatan": "Mahasiswa",           // "Mahasiswa" | "Dosen" | "Kepala Lab"
  "fcm_token": "…",
  "is_active": true,
  "created_at": "<Timestamp>",
  "updated_at": "<Timestamp>"
}
```

### `labs/{labId}`

```jsonc
{
  "nama_lab": "Lab Komputer 1",
  "kapasitas": 40,
  "lokasi": "Gedung B, Lantai 1",
  "fasilitas": ["40 PC", "Proyektor", "AC"],
  "is_active": true
}
```

### `lab_schedules/{scheduleId}`

Jadwal acuan yang diinput Kepala Lab. Menjadi sumber data kalender ketersediaan.

```jsonc
{
  "id_lab": "…",
  "mata_kuliah": "Algoritma dan Pemrograman",
  "nama_dosen": "Dr. Azlan, M.Kom.",
  "tanggal": "2026-09-21",
  "jam_mulai": "08:00",
  "jam_selesai": "10:30",
  "mulai_menit": 480,
  "selesai_menit": 630,
  "tipe": "Reguler",                // "Reguler" | "Pengganti" | "Pemeliharaan"
  "semester": "Ganjil 2026/2027",
  "dibuat_oleh": "<uid Kepala Lab>"
}
```

### `bookings/{bookingId}`

```jsonc
{
  "id_user": "<uid pemohon>",
  "id_lab": "…",
  "mata_kuliah": "Pemrograman Mobile",
  "tanggal": "2026-09-25",
  "jam_mulai": "13:00",
  "jam_selesai": "15:30",
  "mulai_menit": 780,
  "selesai_menit": 930,
  "status": "Menunggu",             // "Menunggu" | "Disetujui" | "Ditolak"
  "nama_pemohon": "Budi Santoso",   // didenormalisasi
  "nomor_identitas_pemohon": "2021010042",
  "catatan": "Kelas pengganti pertemuan ke-5",
  "alasan_penolakan": null,
  "diverifikasi_oleh": null,
  "diverifikasi_pada": null,
  "created_at": "<Timestamp>",
  "updated_at": "<Timestamp>"
}
```

### `slot_locks/{id_lab}_{yyyy-MM-dd}`

Indeks keterisian slot — **turunan**, bukan sumber kebenaran. Inilah yang
membuat pemeriksaan jadwal bentrok bebas *race condition* tanpa Cloud Functions:
seluruh keterisian satu laboratorium pada satu tanggal berada dalam satu dokumen,
sehingga pemeriksaan cukup memakai `DocumentReference` di dalam transaksi.

```jsonc
{
  "id_lab": "aB3xK9...",
  "tanggal": "2026-09-19",
  "slots": {
    "16": "s:jadwal001",   // 08:00–08:30 ditempati jadwal acuan
    "17": "s:jadwal001",
    "20": "b:booking42"    // 10:00–10:30 ditempati pengajuan disetujui
  },
  "updated_at": "<Timestamp>"
}
```

Indeks slot = `menit / 30`. Slot `16` berarti 08:00–08:30. Pemilik ditandai
prefiks `s:` (jadwal) atau `b:` (pengajuan). Penjelasan lengkapnya di
[`docs/ARSITEKTUR.md`](docs/ARSITEKTUR.md#concurrency-control).

> Bila koleksi ini terhapus, kalender tetap tampil benar (dibaca dari
> `lab_schedules` dan `bookings`), tetapi validasi bentrok akan menganggap semua
> slot kosong. Cara membangunnya ulang ada di
> [`docs/CHECKLIST-SETUP.md`](docs/CHECKLIST-SETUP.md).

**Relasi** (setara 1-to-Many pada ERD dokumen tugas):

- 1 `users` → banyak `bookings` (lewat `id_user`)
- 1 `labs` → banyak `bookings` (lewat `id_lab`)
- 1 `labs` → banyak `lab_schedules` (lewat `id_lab`)

**Catatan desain.** `nama_pemohon` dan `nomor_identitas_pemohon` sengaja didenormalisasi agar Kepala Lab dapat menampilkan daftar pengajuan tanpa membaca koleksi `users`. Sebaliknya, nama laboratorium **tidak** didenormalisasi — daftar lab berukuran kecil dan sudah di-cache di provider, jadi selalu ikut terbarui bila lab diganti nama.

---

## Aturan validasi

Aturan yang sama diterapkan berlapis di tiga tempat agar konsisten:

| Aturan | Nilai | Lokasi |
|--------|-------|--------|
| Jam operasional | 08:00 – 21:00 | `AppConfig`, `constants.ts`, `firestore.rules` |
| Durasi maksimum sesi | 4 jam | idem |
| Horizon pengajuan | 60 hari ke depan | idem |
| Tanggal lampau | ditolak | `BookingRepository._validasiDraft` |
| NIM/NIDN | 6–15 digit angka | `Validators.nomorIdentitas` |
| Kata sandi | minimal 8 karakter | `AppConfig.minPasswordLength` |

**Deteksi bentrok.** Dua rentang `[a₁,a₂)` dan `[b₁,b₂)` dinyatakan bentrok bila `a₁ < b₂ && b₁ < a₂`. Bersinggungan saja (selesai 10:00, mulai 10:00) **tidak** dianggap bentrok.

---

## Status pengerjaan

### Sudah selesai

- Struktur project, tema, komponen bersama
- Firebase Auth multi-role (registrasi, login, logout, rollback akun tanpa profil)
- Model data lengkap + enum dengan warna & ikon
- Routing `go_router` dengan guard sesi & peran
- **Kalender ketersediaan lab** real-time (navigasi bulan, filter lab, daftar slot kosong per lab)
- **Input/ubah/hapus jadwal lab** oleh Kepala Lab, dengan peringatan bentrok
- **Formulir pengajuan reservasi** — memilih lab & tanggal, slot kosong ditampilkan
  dan bisa diketuk, peringatan bentrok langsung, validasi durasi & jam operasional
- **Verifikasi jarak jauh** — Setujui/Tolak dari daftar maupun halaman detail,
  penolakan wajib disertai alasan
- **Pembatalan pengajuan** oleh pemohon selama status masih Menunggu
- **Kelola laboratorium** (tambah/ubah/nonaktifkan/hapus) oleh Kepala Lab
- **Push notification dua arah** + notifikasi in-app untuk pesan foreground,
  dengan channel Android berprioritas tinggi dan ketukan yang mengarahkan ke
  daftar pengajuan sesuai peran
- **Anti-*double booking* bebas race condition tanpa Cloud Functions** lewat
  kunci keterisian slot (`slot_locks`) — berjalan penuh di paket Spark/gratis
- Security Rules, composite index, Storage Rules
- Cloud Functions: `submitBooking`, `reviewBooking`, `onBookingCreated`, `onBookingReviewed`
- Skrip seed data & pembuatan akun Kepala Lab
- **62 unit test** untuk logika penjadwalan inti (`computeFreeRanges`,
  `slotsCovered`, `isRentangBentrok`, `bentrokDengan`)
- `flutter analyze` bersih · `flutter test` 62/62 lulus · APK debug berhasil
  dibangun · `tsc --noEmit` bersih

### Tahap berikutnya

1. **Riwayat notifikasi in-app** — koleksi `users/{uid}/notifications` (path sudah
   disiapkan di `FirestorePaths`) beserta lencana belum dibaca.
2. **Upload berkas jadwal** (PDF/Excel) ke Cloud Storage — rules sudah disiapkan
   di `storage.rules`.
3. **Ekspor jadwal ke kalender perangkat** (ICS) dan pengingat H-1 sebelum kelas.
4. **Laporan & ekspor** pengajuan per laboratorium / mata kuliah / semester.
5. **Pengujian otomatis** — unit test untuk `computeFreeRanges()` dan
   `isRentangBentrok()`, serta widget test untuk alur pengajuan.
6. **Mode offline** — Firestore sudah mengaktifkan cache lokal secara bawaan;
   perlu ditinjau agar pengajuan yang dibuat offline tidak menyesatkan pengguna.

---

## Pemecahan masalah

**Aplikasi menampilkan layar "Konfigurasi Firebase diperlukan"**
`flutterfire configure` belum dijalankan, atau `google-services.json` belum ada. Jalankan langkah 2 pada [Langkah setup](#langkah-setup).

**`FirebaseException: [cloud_firestore/permission-denied]` saat mengajukan reservasi**

Telusuri berurutan — tiga penyebab berikut mencakup hampir semua kasus:

1. **Rules belum di-deploy versi terbaru.** Transaksi pengajuan membaca koleksi
   `slot_locks` yang ditambahkan belakangan. Bila rules yang ter-deploy belum
   memuatnya, pembacaan itu jatuh ke aturan penutup `allow read, write: if false`.
   → `firebase deploy --only firestore:rules,firestore:indexes`

2. **Dokumen `users/{uid}` belum punya `is_active: true`.** Rules mensyaratkan
   `isAccountActive()`. Akun yang dibuat manual lewat Console sering melewatkan
   field ini.
   → Periksa Firestore → `users` → dokumen Anda → pastikan `is_active` bertipe
   **boolean** dan bernilai `true`.

3. **Document ID `users` tidak sama dengan UID.** Aplikasi mencari profil lewat
   `users/{uid}`.

**`permission-denied` pada semua operasi (bukan hanya pengajuan)**

Rules belum pernah di-deploy, sehingga mode *Production* masih memakai aturan
bawaan `allow read, write: if false`. Gejalanya: tidak bisa masuk sama sekali,
atau selalu diarahkan ke layar masuk.
→ `firebase deploy --only firestore:rules,firestore:indexes`

**Cara memastikan rules yang ter-deploy sudah benar**

Firebase Console → Firestore → tab **Rules**. Rules yang benar memuat komentar
berbahasa Indonesia dan blok `match` untuk **lima** koleksi: `users`, `labs`,
`lab_schedules`, `bookings`, dan `slot_locks`.

Bila salah satu tidak ada, deploy ulang.

**`The query requires an index`**
Buka tautan pada pesan galat untuk membuat index, atau jalankan `firebase deploy --only firestore:indexes`.

**Kalender kosong padahal jadwal sudah diinput**
Periksa bahwa dokumen `lab_schedules` punya field `tanggal` berformat `yyyy-MM-dd` dan `id_lab` yang cocok dengan document id di koleksi `labs`.

**Notifikasi tidak sampai**
1. Pastikan izin notifikasi diberikan (Profil → Aktifkan izin notifikasi).
2. Kepala Lab harus berlangganan topik `kepala_lab` — otomatis dilakukan saat login.
3. **Channel Android belum terbentuk.** Cloud Functions mengirim notifikasi ke
   channel `mrm_high_importance`. Channel itu dibuat aplikasi saat pertama kali
   dijalankan. Bila aplikasi belum pernah dibuka setelah pemasangan, Android 8+
   akan membuang notifikasi tersebut. Solusi: buka aplikasi sekali, lalu kirim
   ulang pengajuan.
4. Cek log: `firebase functions:log`.

**Notifikasi muncul saat aplikasi dibuka, tetapi tidak saat aplikasi tertutup**
Periksa bahwa `channelId` di `functions/src/notifications.ts` (`CHANNEL_ID`)
sama dengan `NotificationService.channelId` di
`lib/data/services/notification_service.dart`, lalu deploy ulang functions.

**`flutter test` gagal dengan `Invalid WebSocket upgrade request`**
Ada variabel lingkungan proxy (`http_proxy` / `https_proxy`) yang membuat
koneksi WebSocket lokal ke `flutter_tester` ikut diproksikan. Jalankan tanpa
variabel tersebut:

```bash
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter test
```

**Pengajuan ditolak padahal slot terlihat kosong di kalender**
Kalender membaca `bookings` dan `lab_schedules`, sedangkan validasi membaca
`slot_locks`. Bila koleksi `slot_locks` tidak sinkron (mis. data dibuat manual
lewat Console tanpa lewat aplikasi), keduanya bisa berbeda. Periksa dokumen
`slot_locks/{id_lab}_{tanggal}` di Firebase Console — bila ada entri slot yang
seharusnya kosong, hapus entri tersebut.

**`flutter build apk` gagal pada `mergeLibDexDebug`**
Jalankan dari terminal biasa, di luar lingkungan yang membatasi akses tulis ke folder `build/`.

**`flutter build apk` gagal dengan pesan tentang core library desugaring**
`flutter_local_notifications` memerlukan desugaring. Pastikan
`android/app/build.gradle.kts` memuat `isCoreLibraryDesugaringEnabled = true`
dan dependensi `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.

---

## Lisensi & konteks akademik

Dikerjakan sebagai pemenuhan tugas mata kuliah di STMIK Triguna Dharma, berdasarkan dokumen *"Sistem Pengajuan Kelas Pengganti di STMIK Triguna Dharma Berbasis Mobile"*.

**Jangan pernah meng-commit** `tools/seed/serviceAccountKey.json`, `android/app/google-services.json`, atau berkas kunci lain. Keduanya sudah masuk `.gitignore`.
