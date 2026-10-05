# Arsitektur — Mobile Resource Management STMIK Triguna Dharma

Dokumen ini menjelaskan **mengapa** sistem dibangun seperti ini, bukan sekadar apa isinya. Untuk cara menjalankan, lihat [`../README.md`](../README.md).

---

## Daftar isi

1. [Peta lapisan](#peta-lapisan)
2. [Alur data](#alur-data)
3. [Concurrency control](#concurrency-control)
4. [Pemetaan MySQL → Firestore](#pemetaan-mysql--firestore)
5. [Model peran & keamanan](#model-peran--keamanan)
6. [Strategi pembacaan data](#strategi-pembacaan-data)
7. [Alur notifikasi](#alur-notifikasi)
8. [Keputusan desain & trade-off](#keputusan-desain--trade-off)
9. [Rencana tahap berikutnya](#rencana-tahap-berikutnya)

---

## Peta lapisan

```
┌──────────────────────────────────────────────────────────────────────┐
│  features/…/presentation          Widget & halaman                   │
│    KalenderKetersediaanPage · AdminJadwalPage · LoginPage · …        │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ ref.watch / ref.read
┌───────────────────────────▼──────────────────────────────────────────┐
│  features/…/providers            State & turunan (Riverpod)          │
│    authSessionProvider · ketersediaanHariProvider · …                │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────────┐
│  data/repositories               Akses data + aturan domain          │
│    UserRepository · LabRepository · LabScheduleRepository ·          │
│    BookingRepository                                                 │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────────┐
│  data/services                   Pembungkus SDK Firebase             │
│    AuthService · FirestoreService · FunctionsService ·               │
│    NotificationService                                               │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────────────┐
│  Firebase   Auth · Firestore · Functions · Storage · FCM             │
└──────────────────────────────────────────────────────────────────────┘
```

### Aturan ketergantungan

| Lapisan | Boleh bergantung pada | Tidak boleh |
|---------|----------------------|-------------|
| `core/` | Flutter SDK | `data/`, `features/` |
| `data/models` | `core/` | `data/services`, `features/` |
| `data/services` | `core/`, `data/models` | `features/` |
| `data/repositories` | `core/`, `data/models`, `data/services` | `features/` |
| `features/` | apa pun di bawahnya | — |

`core/` sengaja tidak tahu apa-apa soal Firestore maupun fitur, sehingga bisa dipakai ulang dan diuji terpisah. Pengecualiannya hanya `core/errors/app_exception.dart` yang perlu mengenali `FirebaseAuthException` / `FirebaseException` untuk memetakan pesan kesalahan — ini disengaja, karena pemetaan itulah tanggung jawabnya.

### Mengapa UI tidak menyentuh Firestore

Semua akses data lewat repository supaya:

1. **Kesalahan terjemahan terpusat.** Firebase melempar kode seperti `permission-denied`; `guardFirebase()` mengubahnya menjadi `AppException` dengan pesan Indonesia. UI hanya memanggil `.userMessage`.
2. **Model terpisah dari dokumen.** `FirestoreUtils.pick()` menerima `snake_case` **dan** `camelCase`, sehingga dokumen yang dibuat manual lewat Firebase Console tetap terbaca.
3. **Perubahan backend terisolasi.** Kalau nanti pindah dari Firestore ke REST API, hanya `data/services` dan `data/repositories` yang berubah.

---

## Alur data

### A. Sesi pengguna

```
FirebaseAuth.authStateChanges()
        │
        ▼
authSessionProvider (StreamProvider<AuthSession>)
        │  asyncMap: untuk setiap user Firebase → baca users/{uid}
        ▼
   ┌────────────────┬─────────────────────┬──────────────────┐
   │ AuthSignedOut  │ AuthProfileMissing  │ AuthSignedIn     │
   └────────────────┴─────────────────────┴──────────────────┘
        │                    │                     │
        ▼                    ▼                     ▼
   /masuk          /profil-belum-lengkap   /beranda atau /admin/dasbor
```

`AuthSession` dibuat sebagai `sealed class` supaya `switch` di router **wajib** menangani ketiga kemungkinan. Kasus "akun Auth ada tapi profil Firestore belum ada" sering terlewat dan menyebabkan pengguna terjebak di layar kosong; di sini ia ditangani eksplisit dengan halaman tersendiri.

Pemisahan state juga menghindari UI berkedip: `authSessionProvider` menentukan **siapa** pengguna, sedangkan `authControllerProvider` (`AsyncValue<void>`) hanya melacak **proses** login/daftar. Tombol bisa menampilkan spinner tanpa mengubah identitas pengguna.

### B. Kalender ketersediaan

```
jadwalBulananProvider(yyyy-MM)   ──┐
                                   ├──► petaKeterisianBulananProvider(yyyy-MM)
pengajuanBulananProvider(yyyy-MM)─┘         │  Map<yyyy-MM-dd, List<OccupancySlot>>
                                            │
              namaLabProvider ──────────────┘  (cache id → nama_lab)
                                            │
                                            ▼
                          penandaKeterisianProvider  → titik penanda di kalender
                                            │
                                            ▼
                          ketersediaanHariProvider   → kartu per laboratorium
```

Hanya **dua** pembacaan Firestore per bulan yang ditampilkan: satu untuk `lab_schedules`, satu untuk `bookings`. Sisanya adalah turunan di memori.

`OccupancySlot` menyatukan dua sumber berbeda bentuk (jadwal acuan dan pengajuan) menjadi satu tipe. Konsekuensinya, kalender, daftar slot kosong, dan pemeriksaan bentrok semuanya bekerja pada satu struktur data yang sama — tidak ada logika duplikat.

### C. Menghitung slot kosong

`LabDayAvailability.computeFreeRanges()`:

```
1. Buang slot di luar jam operasional, urutkan berdasarkan jam mulai.
2. Gabungkan slot yang saling bersinggungan / tumpang tindih.
3. Selisih antara [jam buka, jam tutup] dengan slot gabungan = waktu kosong.
```

Contoh, jam operasional 08:00–21:00 dengan dua jadwal:

```
08:00      10:30  11:00      14:00                    21:00
  ├──────────┤      ├──────────┤                        │
  │ Terpakai │      │ Terpakai │      kosong            │
  └──────────┘      └──────────┘
  ←──────── kosong ────────→
```

Hasil: `08:00–10:30` terpakai, `10:30–11:00` **kosong**, `11:00–14:00` terpakai, `14:00–21:00` kosong.

---

## Concurrency control

Ini bagian paling penting dari dokumen tugas ("validasi otomatis untuk menolak jadwal yang bentrok"), dan bagian yang paling mudah salah.

### Masalahnya

Pendekatan naif: baca jadwal → cek bentrok → tulis. Dua pengguna yang menekan "Ajukan" pada milidetik yang sama akan sama-sama membaca kondisi "belum ada jadwal", sama-sama lolos, dan sama-sama menulis. Hasilnya *double booking*.

Solusinya transaksi Firestore: pembacaan dan penulisan menjadi satu unit atomik, dan Firestore menggagalkan transaksi bila dokumen yang dibaca berubah sebelum penulisan.

### Kendalanya

Firebase SDK Flutter (`cloud_firestore`) **hanya** menyediakan:

```dart
Future<DocumentSnapshot<T>> get<T extends Object?>(DocumentReference<T> ref);
```

Tidak ada overload untuk `Query`. Artinya di sisi klien kita **tidak bisa** menjalankan query "apakah ada pengajuan yang bentrok?" di dalam transaksi. Tanpa itu, validasi di klien selalu punya celah race condition.

Cloud Functions bisa mengatasinya (Admin SDK mendukung query di dalam transaksi), tetapi **Cloud Functions memerlukan paket Blaze** — di luar jangkauan bila proyek harus 100% gratis.

### Solusinya: kunci keterisian slot

Kuncinya adalah mengubah pertanyaan "apakah ada dokumen yang bentrok?" menjadi pembacaan **satu dokumen yang sudah diketahui ID-nya**.

Seluruh keterisian satu laboratorium pada satu tanggal dipindahkan ke satu dokumen:

```
slot_locks/{id_lab}_{yyyy-MM-dd}
  id_lab:     "aB3xK9..."
  tanggal:    "2026-09-19"
  slots: {
    "16": "s:jadwal001",     // 08:00–08:30 ditempati jadwal
    "17": "s:jadwal001",
    "20": "b:booking42",     // 10:00–10:30 ditempati pengajuan disetujui
  }
  updated_at: <Timestamp>
```

Granularitasnya 30 menit (`AppConfig.slotMinutes`). Rentang bersifat *half-open*: 08:00–10:00 menempati slot 16–19, dan 10:00–12:00 menempati slot 20–23 — keduanya tidak bertabrakan, karena ruangan bebas tepat pukul 10:00.

Dokumen inilah **titik serialisasi**. Transaksi apa pun yang membacanya lalu menulisnya kembali akan dibandingkan versinya oleh Firestore; yang kalah dijalankan ulang. Karena seluruh pemeriksaan kini hanya butuh `DocumentReference`, semuanya sah dilakukan di dalam transaksi — **tanpa Cloud Functions**.

### Bagaimana transaksinya berjalan

**Mengajukan reservasi** (`BookingRepository.createBookingDirect`):

```
1. baca labs/{id_lab}                  -> pastikan laboratorium ada
2. baca slot_locks/{id_lab}_{tanggal}  -> keterisian hari itu
3. slot yang tercakup masih kosong?    -> tidak, lempar galat bentrok
4. tulis bookings/{baru} status Menunggu
```

Perhatikan: pengajuan baru **tidak mengunci slot**. Beberapa pemohon boleh mengajukan waktu yang sama, dan Kepala Laboratorium yang memutuskan. Ini disengaja — kalau pengajuan menunggu ikut mengunci, satu pengajuan yang tidak pernah diverifikasi akan memblokir slot selamanya.

**Menyetujui pengajuan** (`reviewBookingDirect`) — di sinilah slot benar-benar dikunci:

```
1. baca bookings/{id}                  -> pastikan masih Menunggu
2. baca slot_locks/{id_lab}_{tanggal}
3. slot yang tercakup masih kosong?    -> tidak, batalkan dengan pesan bentrok
4. tulis slot_locks  -> slot ditandai "b:{id_booking}"
5. update bookings/{id} status Disetujui
```

Langkah 3 dan 4 berada di transaksi yang sama. Dua persetujuan bersamaan pada jam yang sama akan bertabrakan pada dokumen `slot_locks` yang sama, dan Firestore hanya mengizinkan satu di antaranya.

**Mengelola jadwal lab** (`LabScheduleRepository`) — jadwal tipe `Reguler` dan `Pemeliharaan` juga mengunci slot:

| Operasi | Perlakuan kunci |
|---------|-----------------|
| `createSchedule` | Baca lock → cek → tulis lock `s:{id_schedule}` |
| `updateSchedule` | Baca lock lama & baru → lepas kunci lama → cek rentang baru → pasang kunci baru |
| `deleteSchedule` | Baca lock → lepas kunci milik jadwal tersebut |

`updateSchedule` adalah yang paling berbelit karena harus menangani tiga perubahan sekaligus: rentang waktu, tipe (memblokir ↔ tidak memblokir), dan perpindahan laboratorium atau tanggal. Urutannya selalu: **lepas dulu, baru cek dan pasang**.

### Pesan kesalahan yang informatif

Kunci hanya menyimpan ID pemilik (`b:booking42`), bukan detail jadwalnya. Agar pesan kesalahan tetap berguna, detail pemilik dibaca dari dokumennya — **hanya pada jalur kesalahan**, sehingga tidak menambah biaya pada kasus normal.

Hasilnya pengguna melihat pesan seperti:

> Jadwal bentrok dengan kelas pengganti Pemrograman Mobile oleh Budi Santoso pada 13:00 – 15:30. Silakan pilih slot waktu lain.

Bukan sekadar "jadwal bentrok".

### Jalur Cloud Function

Bila `AppConfig.useCloudFunctionsForBooking` disetel `true` (perlu Blaze), `submitBooking` dan `reviewBooking` mengambil alih. Keduanya **memakai mekanisme kunci slot yang sama**, bukan query.

Ini keputusan yang disengaja. Kalau jalur server memakai query sementara jalur klien memakai kunci, koleksi `slot_locks` akan menjadi tidak konsisten begitu jalur diganti — dan berpindah kembali ke Spark akan menghasilkan validasi yang bocor. Dengan satu mekanisme, berpindah antara Spark dan Blaze tidak mengubah perilaku apa pun.

### Aturan bentrok

Dua rentang `[a₁,a₂)` dan `[b₁,b₂)` dinyatakan bentrok bila:

```
a₁ < b₂  &&  b₁ < a₂
```

Pada kunci slot, aturan yang sama dinyatakan lewat perhitungan indeks:

```dart
// lib/data/models/lab_day_lock.dart
final pertama  = mulaiMenit ~/ 30;
final terakhir = (selesaiMenit - 1) ~/ 30;   // -1 menjaga sifat half-open
```

Aturan ini diterapkan identik di empat tempat:

| Lokasi | Fungsi |
|--------|--------|
| `lib/core/utils/date_time_utils.dart` | `isRentangBentrok()` — dipakai untuk pemeriksaan tampilan |
| `lib/data/models/lab_day_lock.dart` | `slotsCovered()` — inti mekanisme kunci |
| `functions/src/utils.ts` | `slotIndicesCovered()` — sisi server |
| `firestore.rules` | validasi bentuk rentang (`selesai > mulai`, ≤ 4 jam, dalam jam operasional) |

`firestore.rules` tidak bisa menjalankan logika lintas dokumen, jadi ia hanya memvalidasi **bentuk** rentang. Deteksi bentrok antar dokumen adalah tanggung jawab kunci slot.

### Slot mana yang memblokir

| Sumber | Status | Memblokir? | Mengunci slot? |
|--------|--------|-----------|----------------|
| `lab_schedules` tipe `Reguler` | — | ✅ | ✅ |
| `lab_schedules` tipe `Pemeliharaan` | — | ✅ | ✅ |
| `lab_schedules` tipe `Pengganti` | — | ❌ | ❌ |
| `bookings` | `Disetujui` | ✅ | ✅ |
| `bookings` | `Menunggu` | ❌ | ❌ |
| `bookings` | `Ditolak` | ❌ | ❌ |

### Biaya penyimpanan

Satu dokumen per laboratorium per hari, maksimum 26 entri slot. Untuk 5 laboratorium selama setahun: sekitar 1.825 dokumen, masing-masing kurang dari 1 KB — jauh di bawah kuota gratis 1 GiB.

Biaya operasionalnya pun rendah: satu pembacaan dan satu penulisan per pengajuan atau persetujuan, bukan dua query.

### Batasan yang diketahui

Kunci berlaku per **laboratorium per hari**, bukan per rentang waktu. Dua operasi pada laboratorium dan tanggal yang sama akan saling menunggu (serialisasi) meskipun jamnya tidak beririsan. Untuk aplikasi kampus dengan puluhan pengajuan per hari, ini tidak terasa. Granularitas yang lebih halus akan memerlukan satu dokumen per slot, dengan konsekuensi lebih banyak pembacaan per transaksi.


## Pemetaan MySQL → Firestore

Dokumen tugas merancang database relasional (MySQL), sedangkan aplikasi memakai Firebase. Pemetaannya:

### `users`

```sql
CREATE TABLE users(
  id_user INT AUTO_INCREMENT PRIMARY KEY,
  nomor_identitas VARCHAR(20) UNIQUE NOT NULL,
  nama VARCHAR(100) NOT NULL,
  jabatan ENUM('Dosen','Mahasiswa','Kepala Lab') NOT NULL,
  password VARCHAR(255) NOT NULL
);
```

→ koleksi `users`, document id = Firebase Auth UID.

| Kolom | Padanan | Catatan |
|-------|---------|---------|
| `id_user` | document id | = UID, sehingga lookup profil hanya 1 pembacaan |
| `nomor_identitas` | field `nomor_identitas` | keunikan dijamin Firebase Auth (email turunan) |
| `nama` | field `nama` | |
| `jabatan` | field `jabatan` | divalidasi di rules; tidak bisa dipilih sendiri saat registrasi |
| `password` | **tidak disimpan** | dikelola Firebase Authentication (hash di server Google) |

`password` tidak pernah menyentuh database aplikasi. Ini perbaikan keamanan dibanding rancangan awal, di mana kolom `VARCHAR(255)` mengesankan penyimpanan kata sandi langsung.

### `labs` dan `bookings`

Dipetakan apa adanya, dengan penyesuaian:

- `id_lab` / `id_booking` → document id
- `FOREIGN KEY … ON DELETE CASCADE` → tidak ada di Firestore; integritas dijaga Security Rules (mis. `bookings` hanya boleh dibuat bila `id_lab` menunjuk lab yang ada — diperiksa di `submitBooking`)
- `DATE` → `String` `yyyy-MM-dd`
- `TIME` → `String` `HH:mm` **plus** `int` `*_menit`
- `ENUM` → `String` + validasi

### Mengapa tanggal & jam disimpan sebagai string

1. **Zona waktu.** `Timestamp` Firestore adalah UTC. Jadwal "Senin 08:00" adalah waktu dinding lokal; menyimpannya sebagai timestamp membuat jadwal bergeser bila perangkat berpindah zona waktu.
2. **Query rentang tetap murah.** Format `yyyy-MM-dd` terurut secara leksikografis, jadi `where('tanggal', '>=', …)` bekerja persis seperti perbandingan tanggal.
3. **Keterbacaan.** Saat memeriksa data lewat Firebase Console, `2026-09-25` langsung terbaca — berbeda dengan timestamp mentah.

Kolom `mulai_menit` / `selesai_menit` ditambahkan sebagai integer. Tanpa itu, setiap pemeriksaan bentrok harus mem-parsing string `HH:mm` menjadi angka — baik di klien maupun di server. Dengan integer, perbandingannya langsung dan tidak bisa salah parsing.

### Entitas `Status`

Dokumen tugas menyebut `Status` sebagai entitas tersendiri, tetapi DDL-nya hanya berupa kolom `ENUM` pada `bookings`. Mengikuti DDL, status diperlakukan sebagai field, bukan koleksi terpisah — tabel status yang hanya berisi tiga baris tetap akan memerlukan `JOIN` di setiap query tanpa manfaat.

### Entitas tambahan: `lab_schedules`

Dokumen menyebut jadwal lab hanya sebagai "data acuan pada kalender ketersediaan lab" tanpa memodelkannya. Karena kebutuhan fungsional #3 secara eksplisit menyatakan Kepala Laboratorium dapat *menginput/mengunggah jadwal* agar kalender selalu terbarui, jadwal tersebut harus punya tempat penyimpanan. Karena itu ditambahkan koleksi `lab_schedules`.

---

### Entitas tambahan: `slot_locks`

Sama seperti `lab_schedules`, koleksi ini tidak ada di rancangan MySQL karena
rancangan tersebut mengandalkan `FOREIGN KEY` dan query relasional untuk
mendeteksi bentrok. Firestore tidak punya keduanya, dan SDK Flutter tidak bisa
menjalankan query di dalam transaksi — sehingga keterisian slot perlu
direpresentasikan secara eksplisit.

```jsonc
// slot_locks/{id_lab}_{yyyy-MM-dd}
{
  "id_lab": "aB3xK9...",
  "tanggal": "2026-09-19",
  "slots": {
    "16": "s:jadwal001",   // 08:00-08:30
    "17": "s:jadwal001",
    "20": "b:booking42"    // 10:00-10:30
  },
  "updated_at": "<Timestamp>"
}
```

Koleksi ini **turunan**, bukan sumber kebenaran. Sumber kebenarannya tetap
`lab_schedules` dan `bookings`; `slot_locks` adalah indeks yang membuat
pemeriksaan bentrok bisa dijalankan di dalam transaksi. Bila koleksi ini
terhapus, kalender tetap tampil benar (karena membaca `lab_schedules` dan
`bookings`), tetapi validasi bentrok akan menganggap semua slot kosong.

Cara membangunnya ulang ada di [`CHECKLIST-SETUP.md`](CHECKLIST-SETUP.md)
bagian pemulihan data.

## Model peran & keamanan

### Penentuan peran

| Cara | Hasil |
|------|-------|
| Registrasi aplikasi | `Mahasiswa` atau `Dosen` saja |
| `promote-admin.mjs` | `Kepala Lab` |
| Firebase Console | manual (tidak disarankan) |

Rules memaksa hal ini:

```javascript
allow create: if ... && request.resource.data.jabatan in ['Mahasiswa', 'Dosen'];
```

Dan pada `update`, pemilik dokumen tidak boleh menyentuh `jabatan`, `is_active`, maupun `uid`:

```javascript
allow update: if ... && !request.resource.data.diff(resource.data)
                              .affectedKeys()
                              .hasAny(['uid', 'jabatan', 'is_active']);
```

Tanpa batasan ini, siapa pun bisa menulis `jabatan: "Kepala Lab"` ke dokumennya sendiri dan memperoleh hak verifikasi.

### Perlindungan pada `bookings`

Klien tidak boleh:

- membuat pengajuan atas nama orang lain (`id_user == request.auth.uid`),
- menentukan status awal selain `Menunggu`,
- mengisi field verifikasi saat membuat (`diverifikasi_oleh == null`),
- mengubah isi pengajuan saat verifikasi (hanya field verifikasi yang boleh berubah),
- mengubah status pengajuan yang sudah final (`resource.data.status == 'Menunggu'`).

Verifikasi peran juga diulang di `reviewBooking`, karena callable function dapat dipanggil langsung tanpa melewati aplikasi.

### Batasan yang diketahui

`bookings` dapat dibaca oleh **semua** pengguna terverifikasi. Ini diperlukan agar kalender ketersediaan real-time berfungsi untuk semua orang — setara papan jadwal yang tergantung di depan laboratorium. Konsekuensinya, `nama_pemohon` ikut terlihat.

Bila privasi nama perlu dibatasi, alternatifnya adalah memisahkan koleksi publik berisi hanya `{id_lab, tanggal, mulai_menit, selesai_menit, status}`. Belum dilakukan karena menambah kompleksitas sinkronisasi, sementara konteks pemakaiannya adalah lingkungan kampus internal.

---

## Strategi pembacaan data

### Mengapa per bulan, bukan per hari

Kalender menampilkan satu bulan penuh sekaligus. Bila data dibaca per hari, berpindah tanggal berarti query baru setiap kali. Dengan membaca seluruh bulan sekali:

- mengganti tanggal = **nol** pembacaan tambahan,
- titik penanda keterisian di kalender tersedia tanpa query tambahan,
- satu `StreamProvider.family` per bulan, di-cache otomatis oleh Riverpod.

Beban satu bulan jadwal untuk 5 laboratorium sekitar 100–200 dokumen — jauh di bawah batas praktis.

### Mengapa nama laboratorium tidak didenormalisasi

`bookings` menyimpan `id_lab`, bukan `nama_lab`. Nama diselesaikan lewat `namaLabProvider`, yang merupakan `Map<String, String>` hasil turunan dari `daftarLabProvider`.

Alasannya: koleksi `labs` berukuran kecil dan sudah dibaca untuk kebutuhan lain. Menyalin `nama_lab` ke setiap pengajuan akan membuat data usang ketika laboratorium diganti nama.

Sebaliknya, `nama_pemohon` **di**denormalisasi. Koleksi `users` lebih besar, dan menampilkan daftar pengajuan untuk Kepala Lab tanpa denormalisasi berarti satu pembacaan dokumen per baris.

### Kapan `ref.watch` vs `ref.read`

- `ref.watch` di `build()` — untuk nilai yang perubahannya harus membangun ulang UI.
- `ref.read` di callback (`onPressed`, `onTap`) — untuk memanggil aksi sekali tanpa berlangganan.
- `ref.listen` — untuk efek samping (snackbar, navigasi, sinkronisasi token FCM).

Selector dipakai di tempat yang sensitif terhadap rebuild:

```dart
final isLoading = ref.watch(
  authControllerProvider.select((state) => state.isLoading),
);
```

Tanpa `select`, setiap perubahan state autentikasi akan membangun ulang seluruh form.

---

## Keputusan desain & trade-off

### Login memakai NIM/NIDN

**Masalah:** Firebase Auth hanya menerima email; dokumen tugas mensyaratkan NIM/NIDN dan tabel `users` tidak punya kolom email.

**Keputusan:** NIM/NIDN dipetakan ke email internal `{nim}@{domain}`.

**Alternatif yang ditolak:** menambahkan kolom `email` dan meminta pengguna mengisinya. Ditolak karena menyimpang dari rancangan dokumen dan menambah friksi saat registrasi (mahasiswa harus punya email yang bisa diakses).

**Trade-off:** fitur "Lupa kata sandi" bergantung pada email internal yang mungkin tidak aktif. Mitigasinya: reset manual oleh Kepala Lab, didokumentasikan di README.

### State management: Riverpod 3

**Keputusan:** `flutter_riverpod` 3.4.3 dengan API modern (`Notifier`, `AsyncNotifier`), bukan `StateNotifierProvider` yang sudah dipindahkan ke `legacy.dart`.

**Alasan:** dependensi antar-provider eksplisit dan teruji pada waktu kompilasi; mudah mengganti provider saat pengujian; `AsyncValue` menangani loading/error tanpa boilerplate.

**Trade-off:** API Riverpod 3 berbeda dari mayoritas tutorial Riverpod 2 di internet (`valueOrNull` sudah dihapus, `AsyncValue.value` kini nullable). Perlu kehati-hatian bila menyalin contoh dari sumber lama.

### Tanggal sebagai string, bukan `Timestamp`

Sudah dibahas di [Pemetaan MySQL → Firestore](#pemetaan-mysql--firestore). Ringkasnya: menghindari pergeseran zona waktu dan menjaga keterbacaan, dengan `*_menit` sebagai pendamping untuk perhitungan.

### `firebase_options.dart` sebagai placeholder yang aman

**Masalah:** `flutterfire configure` membutuhkan project Firebase pengguna, yang belum tersedia saat kode ini ditulis.

**Keputusan:** berkas berisi nilai placeholder dengan awalan `GANTI_DENGAN_`, dan `main.dart` menangkap kegagalan `Firebase.initializeApp` lalu menampilkan layar panduan konfigurasi (`SetupRequiredApp`).

**Alasan:** layar merah dengan stack trace tidak memberi tahu apa pun. Layar panduan memberi enam langkah konkret beserta perintahnya. Setelah `flutterfire configure` dijalankan, layar tersebut tidak akan muncul lagi.

### Error sebagai `AppException`

Semua kesalahan Firebase dipetakan ke satu tipe dengan pesan Indonesia. `AppException.shouldReport` memungkinkan UI membedakan kesalahan yang perlu ditampilkan dari pembatalan oleh pengguna (mis. menutup dialog).

### Widget bersama di `core/widgets`

`PrimaryButton`, `AppTextField`, `StatusBadge`, `EmptyState`, `ErrorStateView`, `AsyncValueView`, `InfoBanner` — semuanya dipakai lintas fitur. `AsyncValueView` khususnya menghapus pengulangan `.when(loading: …, error: …, data: …)` di setiap halaman.

### Satu formulir pengajuan, bukan satu per pintu masuk

Formulir pengajuan dapat dibuka dari tiga tempat: kalender (tombol per laboratorium),
aksi cepat di Beranda, dan tombol "Ajukan" di tab Pengajuan. Ketiganya memanggil
`FormPengajuanSheet.tampilkan()` yang sama, dengan parameter opsional `idLabAwal`
dan `tanggalAwal`.

Alternatifnya — memilih lab & tanggal di halaman terpisah sebelum membuka formulir —
ditolak karena menambah satu langkah navigasi untuk kasus yang paling sering
(pengguna sudah tahu lab dan tanggal yang diinginkan dari kalender).

### Notifikasi lokal: `flutter_local_notifications`

**Masalah:** FCM tidak menampilkan notifikasi sistem saat aplikasi sedang dibuka.
Tanpa penanganan tambahan, notifikasi yang tiba pada kondisi foreground hilang
tanpa jejak.

**Keputusan:** menambahkan `flutter_local_notifications` untuk menampilkan pesan
foreground, sekaligus sebagai tempat membuat channel Android berprioritas tinggi.

**Trade-off:** satu dependensi native tambahan, dan aplikasi wajib memuat
desugaring Java (`isCoreLibraryDesugaringEnabled = true`) di
`android/app/build.gradle.kts`. Sebagai imbalannya, notifikasi tampil konsisten di
ketiga kondisi aplikasi (foreground, latar, tertutup) dengan suara dan prioritas
yang sama.

### Validasi berlapis, dengan satu sumber kebenaran

Aturan jadwal (jam operasional 08:00–21:00, durasi maksimum 4 jam, horizon 60 hari)
muncul di **empat** tempat: `AppConfig`, `functions/src/constants.ts`,
`firestore.rules`, dan `BookingRepository`. Ini memang duplikasi, tetapi disengaja:
setiap lapisan melindungi dari ancaman yang berbeda.

| Lapisan | Melindungi dari |
|---------|-----------------|
| Formulir (UI) | Salah input yang tidak disengaja — umpan balik tercepat |
| `BookingRepository` | Pemanggilan langsung dari kode lain tanpa lewat UI |
| `firestore.rules` | Penulisan langsung ke Firestore API (melewati aplikasi) |
| Cloud Functions | Klien yang dimodifikasi / pemanggilan callable langsung |

Yang penting: **hanya Cloud Function yang boleh dianggap otoritatif** untuk deteksi
bentrok. Tiga lapisan lainnya bersifat pencegahan, bukan jaminan.

---

## Alur notifikasi

```
Pemohon menekan "Kirim pengajuan"
        │
        ▼
Cloud Function submitBooking  ──►  menulis dokumen bookings
                                        │
                        ┌───────────────┴───────────────┐
                        ▼                               ▼
        onDocumentCreated (trigger)          Klien pemohon (stream Firestore)
        → FCM ke topik kepala_lab            → kalender & daftar ikut terbarui
                        │
                        ▼
        Kepala Lab menerima notifikasi
        → mengetuk → diarahkan ke tab Verifikasi
                        │
                        ▼
        Menyetujui / menolak lewat halaman detail
                        │
                        ▼
        Cloud Function reviewBooking / update Firestore
                        │
                        ▼
        onDocumentUpdated (trigger)  ──►  FCM ke token pemohon
                                              │
                                              ▼
                              Pemohon menerima notifikasi status
                              → mengetuk → diarahkan ke tab Pengajuan
```

### Dua jenis notifikasi di sisi klien

| Kondisi aplikasi | Yang menampilkan | Alasan |
|------------------|------------------|--------|
| **Latar belakang / tertutup** | Android (sistem) via FCM | Aplikasi tidak berjalan, jadi sistem yang menampilkan |
| **Foreground** (sedang dibuka) | `flutter_local_notifications` | FCM **tidak** menampilkan notifikasi sistem saat aplikasi aktif; tanpa ini notifikasi hilang begitu saja |

`NotificationBridge` menjembatani keduanya: pesan dari `FirebaseMessaging.onMessage`
diteruskan ke `NotificationService.showLocalNotification()`.

### Channel Android — hal yang mudah terlewat

Sejak Android 8, notifikasi **wajib** punya channel. Bila payload FCM menyetel
`channelId` yang belum ada di perangkat, notifikasi tersebut **dibuang tanpa pesan galat**.

Karena itu ada kontrak yang harus dijaga:

| Lokasi | Nilai |
|--------|-------|
| `functions/src/constants.ts` → `CHANNEL_ID` | `mrm_high_importance` |
| `lib/data/services/notification_service.dart` → `NotificationService.channelId` | `mrm_high_importance` |

Channel dibuat saat aplikasi pertama dijalankan
(`NotificationService.initializeLocalNotifications` → `_buatChannel`). Konsekuensinya:
aplikasi harus dibuka minimal sekali sebelum notifikasi bisa tampil. Ini dicatat pada
bagian pemecahan masalah README.

### Mengapa penanganan ketukan ada di `NotificationBridge`, bukan di halaman

Tujuan navigasi bergantung pada **peran**, dan peran baru diketahui setelah
`authSessionProvider` memancarkan data. Bridge adalah satu-satunya widget yang
selalu hidup dan punya akses ke `ref`, sehingga cocok untuk:

- menyimpan `getInitialMessage()` sampai sesi diketahui (`_pesanAwal`), lalu
  mengarahkannya — tanpa ini, aplikasi yang dibuka dari notifikasi akan gagal
  bernavigasi karena status login belum termuat;
- memilih tujuan: pemohon → `/pengajuan`, Kepala Lab → `/admin/verifikasi`.

Navigasi dilakukan lewat `ref.read(routerProvider).go(...)` karena bridge berada
**di atas** `MaterialApp.router` sehingga tidak punya `BuildContext` berisi router.

---

## Rencana tahap berikutnya

### 1. Riwayat notifikasi in-app

- Simpan setiap notifikasi ke `users/{uid}/notifications` (path sudah ada di
  `FirestorePaths.notifications`).
- Tampilkan lencana "belum dibaca" pada tab Pengajuan / Verifikasi.
- Bermanfaat ketika notifikasi terlewat atau dihapus dari panel notifikasi.

### 2. Upload berkas jadwal

- `firebase_storage` + `file_picker`.
- `storage.rules` sudah siap (`/jadwal/{fileName}`, maksimum 10 MB, hanya Kepala Lab).
- Simpan URL unduhan pada dokumen `lab_schedules` sebagai lampiran.

### 3. Ekspor & pengingat

- Ekspor jadwal yang disetujui ke kalender perangkat (format ICS).
- Pengingat H-1 sebelum kelas pengganti — memerlukan
  `flutter_local_notifications` dengan penjadwalan (`zonedSchedule`) dan izin
  `SCHEDULE_EXACT_ALARM` pada Android 12+.

### 4. Laporan

- Rekap pengajuan per laboratorium / per mata kuliah / per semester.
- Ekspor CSV atau PDF.
- Pertimbangkan `count()` aggregation query Firestore untuk ringkasan tanpa
  membaca seluruh dokumen.

### 5. Pengujian otomatis

Fungsi murni yang paling layak diuji lebih dulu:

| Fungsi | Berkas | Kasus uji |
|--------|--------|-----------|
| `isRentangBentrok()` | `core/utils/date_time_utils.dart` | Bersinggungan tepat di batas; rentang nol menit; rentang bersarang |
| `computeFreeRanges()` | `data/models/occupancy.dart` | Slot bertumpuk; slot di luar jam operasional; hari penuh; hari kosong |
| `buildDayAvailability()` | `features/calendar/providers/calendar_providers.dart` | Slot milik lab lain tidak ikut terhitung |
| `IdentityUtils.toInternalEmail()` | `core/utils/identity_utils.dart` | NIM dengan spasi / karakter tidak valid |

`computeFreeRanges()` sengaja dibuat sebagai fungsi murni tanpa ketergantungan
Firebase agar bisa diuji langsung.

### 6. Mode offline

Firestore sudah mengaktifkan cache lokal secara bawaan, sehingga daftar dan
kalender tetap terbaca tanpa jaringan. Yang perlu ditinjau: pengajuan yang dibuat
saat offline akan tampak "berhasil" padahal validasi bentrok di server belum
berjalan. Pertimbangkan menonaktifkan penulisan saat offline, atau menandai
pengajuan tersebut sebagai "menunggu sinkronisasi".
