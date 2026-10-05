# Checklist Setup & Urutan Implementasi

Project Firebase: **`fir-test-3168e`**
  
Package Android: `id.ac.trigunadharma.mobile_resource_management`

Status di bawah ini **diverifikasi langsung dari berkas proyek**, bukan dari asumsi.
  
Centang dari atas ke bawah — setiap langkah punya cara verifikasi sendiri.

---


## Ringkasan status

| #  | Langkah                                       | Status               | Bukti                                                          |
| -- | --------------------------------------------- | -------------------- | -------------------------------------------------------------- |
| 1  | `flutterfire configure` dijalankan            | ✅ Selesai            | `firebase.json` punya bagian `flutter.platforms`               |
| 2  | Plugin Gradle `google-services` terpasang     | ✅ Selesai            | `android/settings.gradle.kts` + `android/app/build.gradle.kts` |
| 3  | `google-services.json` tersedia               | ✅ Selesai            | `android/app/google-services.json` (package cocok)             |
| 4  | `lib/firebase_options.dart` berisi nilai asli | ✅ Selesai            | 5 field cocok dengan `google-services.json`                    |
| 5  | Dependensi Cloud Functions terpasang          | ✅ Selesai            | `functions/node_modules` ada                                   |
| 6  | `flutter analyze` bersih                      | ✅ Selesai            | 62 berkas Dart, tanpa temuan                                   |
| 7  | **Project ditautkan ke Firebase CLI**         | ❌ Belum              | `.firebaserc` tidak ada                                        |
| 8  | **Firestore Database dibuat**                 | ❓ Perlu dicek        | Dilakukan di Console                                           |
| 9  | **Provider Email/Password diaktifkan**        | ❓ Perlu dicek        | Dilakukan di Console                                           |
| 10 | **Security Rules & index di-deploy**          | ❌ Belum              | —                                                              |
| 11 | Cloud Functions di-deploy                     | ⚙️ Hanya jalur Blaze | Lihat [A4](#a4-deploy-cloud-functions--hanya-jalur-blaze)      |
| 12 | Jalur produksi diaktifkan                     | ⚙️ Hanya jalur Blaze | Lihat [A5](#a5-aktifkan-jalur-produksi--hanya-jalur-blaze)     |
| 13 | **Data laboratorium di-seed**                 | ❌ Belum              | `tools/seed/node_modules` belum ada                            |
| 14 | **Akun Kepala Lab dibuat**                    | ❌ Belum              | —                                                              |

Nomor **7 sampai 14** adalah sisa pekerjaan. Urutannya penting — lihat [Bagian B](#bagian-b--urutan-yang-disarankan).

> **Belum memutuskan Spark atau Blaze?** Baca
>   
> [`BIAYA-DAN-KUOTA.md`](BIAYA-DAN-KUOTA.md) dulu. Langkah 11 dan 12 hanya berlaku
>   
> bila Anda memilih Blaze; di Spark keduanya dilewati dan aplikasi tetap berjalan
>   
> penuh kecuali validasi bentrok di server serta notifikasi otomatis.

---

## Bagian A — Konfigurasi yang perlu disiapkan


### A1. Aktifkan layanan di Firebase Console

Semuanya **manual** — tidak bisa lewat CLI. Buka
  
[console.firebase.google.com](https://console.firebase.google.com) → pilih project `fir-test-3168e`.

- [ ] **Authentication** → tab *Sign-in method* → aktifkan **Email/Password**
  > Wajib. Tanpa ini, registrasi gagal dengan `operation-not-allowed`.
  >   
  > Google Sign-In **tidak** dipakai — login memakai NIM/NIDN yang dipetakan ke email internal.
- [ ] **Firestore Database** → *Create database* → pilih **Production mode** → lokasi **`asia-southeast2` (Jakarta)**
  > Pilih Jakarta agar latensi rendah dan **konsisten dengan region Cloud Functions**.
  >   
  > Region tidak bisa diubah setelah dibuat.
  >   
  > Mode *Production* dipilih karena Security Rules sudah disiapkan — jangan pakai *Test mode*.
- [ ] **Cloud Messaging** — tidak ada yang perlu diaktifkan, sudah aktif otomatis
- [ ] **Tentukan jalur biaya** — Spark (gratis) atau Blaze (pay-as-you-go)

  Ini keputusan yang memengaruhi langkah A4 dan A5. Baca
    
  [`BIAYA-DAN-KUOTA.md`](BIAYA-DAN-KUOTA.md) sebelum memutuskan.
  |                               | **Spark — Rp0 dijamin** | **Blaze — Rp0 selama dalam kuota** |
  | ----------------------------- | ----------------------- | ---------------------------------- |
  | Cloud Functions               | ❌ tidak bisa di-deploy  | ✅                                  |
  | Validasi bentrok di server    | ❌ (pakai jalur klien)   | ✅                                  |
  | Cloud Storage (upload berkas) | ❌                       | ✅                                  |
  | Firestore, Auth, FCM          | ✅                       | ✅                                  |
  | Risiko tagihan                | **Nol**                 | Ada, walau kecil                   |
  - Pilih **Spark** bila tujuan Anda jaminan mutlak tanpa biaya. **Lewati A4 dan A5**,
      
    dan baca [Jalur C](BIAYA-DAN-KUOTA.md#jalur-c--spark-murni-dengan-validasi-bentrok-yang-benar)
      
    untuk cara mendapatkan validasi bentrok yang tetap benar.
  - Pilih **Blaze** bila Anda menginginkan validasi bentrok transaksional di server.
      
    Tetap Rp0 selama dalam kuota, **kecuali** Cloud Functions yang bisa menimbulkan
      
    biaya kecil meski dalam kuota gratis. Pasang budget alert — tetapi ingat, alert
      
    hanya memberi tahu, **tidak** menghentikan pengeluaran.
- [ ] **Cloud Storage** → *Get started* → region `asia-southeast2`
  > **Hanya bisa dilakukan di Blaze.** Sejak perubahan September 2024, bucket
  >   
  > default baru tidak dapat dibuat di Spark. Baru dipakai pada tahap "upload
  >   
  > berkas jadwal", jadi aman ditunda bila Anda memilih Spark.

**Cara verifikasi:** Authentication menampilkan Email/Password sebagai *Enabled*;
  
Firestore menampilkan tab *Data* yang kosong (bukan tombol "Create database").

---

### A2. Tautkan project ke Firebase CLI

Jalankan di **terminal biasa** (bukan dari dalam aplikasi ini — lihat [Catatan lingkungan](#catatan-lingkungan)):

```bash
firebase login
firebase use fir-test-3168e
```

**Cara verifikasi:** muncul berkas `.firebaserc` di akar project berisi:

```json
{ "projects": { "default": "fir-test-3168e" } }
```

---

### A3. Deploy Security Rules dan index

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Bila Anda memilih Blaze **dan** sudah mengaktifkan Storage, tambahkan:

```bash
firebase deploy --only storage
```



> ⚠️ Di Spark, **jangan** menyertakan `storage` atau `functions` pada perintah deploy —
>   
> keduanya akan gagal karena layanannya belum tersedia.

**Cara verifikasi:**

- Firestore → tab *Rules* menampilkan isi `firestore.rules` (bukan rules bawaan
    
  `allow read, write: if false`). Pastikan aturan untuk `users`, `labs`,
    
  `lab_schedules`, `bookings`, dan **`slot_locks`** semuanya ada.
- Firestore → tab *Indexes* menampilkan 8 composite index dari
    
  `firestore.indexes.json`. Statusnya *Building* lalu *Enabled* (1–5 menit).

> **Kenapa harus sebelum uji coba?** Tanpa rules, aplikasi akan gagal dengan
>   
> `permission-denied` di hampir semua layar, dan pesannya tidak jelas asalnya.

---

### A4. Deploy Cloud Functions — **hanya jalur Blaze**

> **Lewati langkah ini bila Anda memilih Spark.** Cloud Functions tidak dapat
>   
> di-deploy di Spark.

```bash
firebase deploy --only functions
```

**Cara verifikasi:** Firebase Console → *Functions* menampilkan **4 function**:

| Function            | Jenis                      |
| ------------------- | -------------------------- |
| `submitBooking`     | Callable (asia-southeast2) |
| `reviewBooking`     | Callable (asia-southeast2) |
| `onBookingCreated`  | Firestore trigger          |
| `onBookingReviewed` | Firestore trigger          |

> Deploy pertama bisa memakan 5–10 menit karena Cloud Build menyiapkan container.
>   
> Bila gagal dengan pesan soal API yang belum aktif, buka tautan pada pesan galat
>   
> untuk mengaktifkan API tersebut, lalu ulangi.

---

### A5. Aktifkan jalur produksi — **hanya jalur Blaze**

> **Lewati langkah ini bila Anda memilih Spark.** Biarkan nilainya `false`.

Setelah A4 berhasil, ubah satu baris di `lib/core/config/app_config.dart`:

```dart
static const bool useCloudFunctionsForBooking = true;
```

**Kenapa penting:** selama masih `false`, validasi bentrok berjalan di sisi klien
  
dan **tidak bebas race condition**. Hanya setelah `true`, `submitBooking` yang
  
menjalankan pemeriksaan di dalam transaksi server.

**Cara verifikasi:** buat dua pengajuan pada slot yang sama dari dua akun berbeda —
  
yang kedua harus ditolak dengan pesan bentrok.

---

### A6. Isi data laboratorium

```bash
cd tools/seed
npm install
```

Unduh service account key: Firebase Console → ⚙ *Project settings* → tab
  
*Service accounts* → **Generate new private key** → simpan sebagai
  
`tools/seed/serviceAccountKey.json`.

```bash
node seed.mjs
```

**Cara verifikasi:** Firestore menampilkan koleksi `labs` berisi 5 dokumen dan
  
`lab_schedules` berisi ratusan dokumen.

> ⚠️ `serviceAccountKey.json` adalah kredensial rahasia. Sudah masuk `.gitignore` —
>   
> jangan pernah di-commit atau dikirim lewat chat.

---

### A7. Buat akun Kepala Laboratorium

Akun ini tidak bisa dibuat lewat halaman registrasi aplikasi — registrasi hanya
menerima `Mahasiswa` dan `Dosen`. Pilih salah satu cara:

**Cara 1 — Firebase Console** (tanpa berkas rahasia; cocok bila Anda tidak
memakai skrip seed):

1. **Authentication** → *Users* → **Add user**
   Email: `<NIDN>@trigunadharma.ac.id` — mis. `9999000001@trigunadharma.ac.id`
   Password: minimal 8 karakter
2. Salin **UID** pengguna tersebut
3. **Firestore** → koleksi `users` → **Add document**
   **Document ID** = UID tadi (bukan Auto-ID)

   | Field | Tipe | Nilai |
   |-------|------|-------|
   | `uid` | string | UID yang sama |
   | `nomor_identitas` | string | `9999000001` |
   | `nama` | string | Nama lengkap |
   | `email` | string | Email internal tadi |
   | `jabatan` | string | **`Kepala Lab`** |
   | `is_active` | boolean | `true` |

**Cara 2 — Skrip** (butuh `serviceAccountKey.json`):

```bash
cd tools/seed
node promote-admin.mjs --identitas=9999000001 \
  --nama="Kepala Lab STMIK TD" --password=KataSandiKuat123
```

> ### PENTING: `jabatan` harus persis `Kepala Lab`
>
> Security Rules membandingkan string secara persis
> (`profile().jabatan == 'Kepala Lab'`). Menulis `Admin`, `admin`,
> `Kepala Laboratorium`, atau `kalab` membuat akun itu **bukan** Kepala Lab di
> mata rules — semua tindakan verifikasi dan pengelolaan jadwal akan ditolak
> `permission-denied` tanpa penjelasan.
>
> Aplikasi kini bersikap tegas pula: nilai tak dikenal diperlakukan sebagai
> Mahasiswa, dan layar **Profil** menampilkan peringatan berisi nilai mentahnya.

**Cara verifikasi:** masuk memakai **NIDN** `9999000001` (bukan email) → Anda
harus langsung diarahkan ke **Dasbor Kepala Lab**, dan navigasi bawah
menampilkan Dasbor / Jadwal / Verifikasi / Profil.

Bila Anda diarahkan ke Beranda mahasiswa, periksa kembali nilai `jabatan` pada
dokumen `users` — kemungkinan ada salah tulis.

---


### A8. Jalankan aplikasi

```bash
flutter run
```

**Cara verifikasi — uji terima minimal:**

1. **Registrasi** — daftar dengan NIM 10 digit, jabatan Mahasiswa → masuk ke Beranda
2. **Kalender** — tab Kalender menampilkan jadwal dari seed, slot kosong berwarna hijau
3. **Pengajuan** — tekan "Ajukan kelas pengganti" pada salah satu kartu lab →
     
   isi mata kuliah → Kirim → muncul di tab Pengajuan dengan status **Menunggu**
4. **Verifikasi** — keluar, masuk sebagai `9999000001` → tab Verifikasi menampilkan
     
   pengajuan tadi → ketuk → **Setujui**
5. **Notifikasi** — kembali masuk sebagai mahasiswa → notifikasi status masuk →
     
   kalender kini menampilkan slot tersebut sebagai terpakai
6. **Bentrok** — coba ajukan slot yang sama → harus ditolak dengan pesan bentrok

Bila keenam langkah ini lolos, sistem sudah berjalan end-to-end.

---

## Bagian B — Urutan yang disarankan

Urutan ini disusun berdasarkan **ketergantungan**, bukan tingkat kesulitan.
  
Jangan lompat ke B3 sebelum B1 dan B2 selesai.

### B1. Selesaikan Bagian A (A1 → A8)

Tanpa ini, aplikasi hanya menampilkan layar kosong atau galat izin. Tidak ada
  
gunanya menambah fitur sebelum alur dasar terbukti jalan.

Di **jalur Spark**, lewati A4 dan A5 — keduanya khusus Blaze. Sisanya sama.

**Perkiraan waktu:** 30–60 menit, mayoritas menunggu deploy dan index building.
  
Di jalur Spark lebih cepat karena tidak ada deploy Cloud Functions.


### B2. Verifikasi perilaku anti-bentrok

Ini kebutuhan paling kritis pada dokumen tugas, dan paling mudah salah.
  
Cara verifikasinya bergantung pada jalur yang Anda pilih.

**Jalur Blaze** — validasi dijalankan server:

- Uji dua pengajuan bersamaan pada slot yang sama (dua akun, dua perangkat/emulator).
- Pastikan yang kedua ditolak **oleh server**, bukan hanya oleh UI. Cara
    
  membuktikan: matikan sementara validasi klien dengan mengubah `_cariBentrok()`
    
  agar selalu mengembalikan `null`, lalu ulangi. Server tetap harus menolak.

**Jalur Spark** — validasi dijalankan lewat kunci keterisian slot:

- Uji alur normal: ajukan slot yang sudah terpakai → harus ditolak dengan pesan
    
  bentrok yang menyebut mata kuliah dan jamnya.
- Uji jadwal: buat jadwal lab pada slot yang sudah dipesan pengajuan disetujui →
    
  harus ditolak.
- Uji pelepasan: hapus jadwal lab → slotnya harus bisa diajukan kembali.
- Uji persetujuan ganda: siapkan dua pengajuan `Menunggu` pada jam yang sama,
    
  lalu setujui keduanya → yang kedua harus ditolak dengan pesan bentrok.

**Bukti bahwa validasi benar-benar dari sistem, bukan dari UI:** buka Firebase
  
Console → koleksi `slot_locks`. Setelah pengajuan disetujui, dokumen
  
`{id_lab}_{tanggal}` harus memuat entri `"16": "b:{id_booking}"` dan seterusnya
  
untuk setiap slot yang tercakup. Kalau entri itu ada, penguncian bekerja.

**Kalau lolos:** fondasi keamanan jadwal sudah benar dan **bebas race condition**,
  
baik di jalur Spark maupun Blaze.
  
Kalau tidak, perbaiki dulu sebelum lanjut — semua fitur berikutnya bergantung
  
pada ini.


### B3. Tambahkan pengujian otomatis

Fungsi murni berikut bisa diuji tanpa Firebase maupun perangkat, dan justru
  
di sinilah bug paling mahal bersembunyi:

| Prioritas | Fungsi                            | Berkas                                                | Kasus yang wajib diuji                                                                                        |
| --------- | --------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1         | `computeFreeRanges()`             | `data/models/occupancy.dart`                          | Slot bertumpuk, slot di luar jam operasional, hari penuh, hari kosong, slot bersinggungan tepat di batas      |
| 2         | `isRentangBentrok()`              | `core/utils/date_time_utils.dart`                     | Bersinggungan di batas (08:00–10:00 vs 10:00–12:00 = **tidak** bentrok), rentang nol menit, rentang bersarang |
| 3         | `buildDayAvailability()`          | `features/calendar/providers/calendar_providers.dart` | Slot milik lab lain tidak ikut terhitung                                                                      |
| 4         | `IdentityUtils.toInternalEmail()` | `core/utils/identity_utils.dart`                      | NIM dengan spasi / karakter tidak valid                                                                       |
| 5         | `Booking.bentrokDengan()`         | `data/models/booking.dart`                            | Lab berbeda, tanggal berbeda, pengajuan yang sama                                                             |

Jalankan dengan `flutter test`. Target: seluruhnya hijau sebelum menambah fitur baru.

### B4. Lengkapi fitur yang belum ada

Urut dari yang paling kecil risikonya:

1. **Riwayat notifikasi in-app** — koleksi `users/{uid}/notifications`
     
   (path sudah disiapkan di `FirestorePaths`). Bermanfaat bila notifikasi terlewat.
     
   **Bisa dikerjakan di Spark**, tetapi tanpa Cloud Functions riwayat hanya terisi
     
   saat aplikasi sedang dibuka.
2. **Laporan & ekspor** — rekap per laboratorium / mata kuliah / semester.
     
   Bisa memakai `count()` aggregation agar tidak membaca seluruh dokumen.
     
   **Sepenuhnya bisa di Spark.**
3. **Upload berkas jadwal** — `firebase_storage` + `file_picker`.
     
   ⚠️ **Butuh Blaze** (bucket Storage baru tidak bisa dibuat di Spark). Alternatif
     
   tanpa biaya: simpan berkas di Google Drive / server kampus, lalu simpan hanya
     
   tautannya di Firestore.
4. **Ekspor ICS + pengingat H-1** — perlu izin `SCHEDULE_EXACT_ALARM` di Android 12+.
     
   **Sepenuhnya bisa di Spark** (notifikasi lokal, tidak lewat server).


### B5. Kunci keamanan dan pantau biaya

Sebelum dipakai nyata:

- [ ] **Jangan pasang metode pembayaran** bila Anda memilih jalur Spark. Ini
    
  jaminan tunggal paling kuat: tanpa metode pembayaran, tagihan mustahil terjadi.
- [ ] **App Check** — aktifkan dengan Play Integrity. Mencegah klien tidak resmi
    
  memanggil Firestore meski punya `apiKey` (yang memang tidak rahasia).
    
  Tersedia di Spark maupun Blaze.
- [ ] **Budget alert** di Google Cloud Console (hanya relevan di Blaze) — mis.
    
  notifikasi pada $1 dan $5. Ingat: alert **tidak** menghentikan pengeluaran,
    
  hanya memberi tahu.
- [ ] **Pantau kuota** — Firebase Console → ⚙ *Project settings* → *Usage and billing*.
    
  Bandingkan dengan batas 50.000 baca dan 20.000 tulis per hari.
- [ ] **Tinjau `firestore.rules`** — terutama keputusan bahwa `bookings` dapat dibaca
    
  semua pengguna terverifikasi (dibutuhkan agar kalender real-time berfungsi).
- [ ] **Cadangkan data** — Firestore mendukung ekspor terjadwal, tetapi fitur ini
    
  **butuh billing**. Di Spark, lakukan ekspor manual lewat Console bila perlu.
- [ ] **Nonaktifkan akun uji coba** sebelum diserahkan.

### B6. Hardening yang mudah ditunda

- Mode offline: pengajuan yang dibuat tanpa jaringan akan tampak "berhasil"
    
  padahal validasi server belum berjalan. Pertimbangkan menonaktifkan penulisan
    
  saat offline atau menandainya "menunggu sinkronisasi".
- Restrukturisasi `bookings` bila privasi nama pemohon perlu dibatasi
    
  (lihat `docs/ARSITEKTUR.md` bagian "Batasan yang diketahui").

---

## Pemulihan data


### `slot_locks` tidak sinkron

**Gejala:** kalender menampilkan slot sebagai kosong, tetapi pengajuan ditolak
  
dengan pesan bentrok. Atau sebaliknya — slot yang jelas terpakai bisa diajukan.

**Sebab:** koleksi `slot_locks` adalah indeks turunan. Ia bisa tidak sinkron bila
  
data `lab_schedules` atau `bookings` diubah langsung lewat Firebase Console
  
(bukan lewat aplikasi), atau bila dokumennya terhapus.

**Perbaikan:**

1. Hapus seluruh dokumen pada koleksi `slot_locks` (Console → Firestore →
     
   pilih koleksi → hapus dokumen).
2. Bangun ulang lewat aplikasi:
   - Masuk sebagai Kepala Laboratorium
   - Tab **Jadwal** → buka setiap tanggal yang punya jadwal → ketuk jadwal →
       
     ubah → simpan tanpa mengubah apa pun
   - Ini memicu `updateSchedule` yang melepas lalu memasang ulang kuncinya
3. Untuk pengajuan yang sudah disetujui, kuncinya dipasang saat persetujuan.
     
   Bila ada pengajuan disetujui yang kuncinya hilang, tolak lalu minta pemohon
     
   mengajukan ulang — atau setel entri `slots` secara manual di Console dengan
     
   format `"<indeks>": "b:<id_booking>"`.

**Pencegahan:** jangan mengubah `lab_schedules` atau `bookings` langsung dari
  
Console. Gunakan aplikasi, atau `tools/seed/seed.mjs` yang sudah menulis kunci
  
slot dengan benar.

### Menghitung indeks slot secara manual

Indeks slot = `menit sejak tengah malam / 30`.

| Jam   | Menit | Indeks slot            |
| ----- | ----- | ---------------------- |
| 08:00 | 480   | 16                     |
| 08:30 | 510   | 17                     |
| 09:00 | 540   | 18                     |
| 10:00 | 600   | 20                     |
| 21:00 | 1260  | 42 (di luar jangkauan) |

Slot terakhir yang valid adalah indeks **41** (20:30–21:00).

Rentang `[mulai, selesai)` mencakup indeks dari `mulai/30` sampai
  
`(selesai - 1)/30`. Contoh: 08:00–10:00 → indeks 16, 17, 18, 19.

---

## Catatan lingkungan

**Firebase CLI tidak bisa dijalankan dari dalam sesi asisten ini.** Perintah
  
`firebase` gagal dengan:

```
Error: EPERM: operation not permitted, open 'C:\Users\HP\.config\configstore\firebase-tools.json'
```

Penyebabnya pembatasan akses tulis ke folder konfigurasi pengguna, bukan masalah
  
pada project. **Jalankan seluruh perintah `firebase` dari terminal Anda sendiri**
  
(PowerShell / Command Prompt / Git Bash). Semua perintah di dokumen ini dirancang
  
untuk dijalankan manual.

---

## Rujukan

| Dokumen                                                        | Isi                                                                            |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [`BIAYA-DAN-KUOTA.md`](BIAYA-DAN-KUOTA.md)                     | Spark vs Blaze, Production vs Test mode, kuota gratis, cara tetap Rp0          |
| [`../README.md`](../README.md)                                 | Cara menjalankan, skema data Firestore, pemecahan masalah                      |
| [`ARSITEKTUR.md`](ARSITEKTUR.md)                               | Peta lapisan, alur data, penjelasan concurrency control, keputusan & trade-off |
| [`../firestore.rules`](../firestore.rules)                     | Security Rules dengan komentar alasan tiap aturan                              |
| [`../functions/src/bookings.ts`](../functions/src/bookings.ts) | Implementasi validasi bentrok transaksional (butuh Blaze)                      |
