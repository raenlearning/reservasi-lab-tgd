# Biaya & Kuota Firebase — Panduan Mode 100% Gratis

Dokumen ini menjawab satu pertanyaan: **bisakah proyek ini berjalan tanpa keluar biaya sepeser pun, dan apa yang harus dikorbankan?**

Jawaban singkatnya: **bisa**, dengan satu konsekuensi penting yang dijelaskan di  
[Bagian D](#bagian-d--konsekuensi-terhadap-proyek-ini).

> Angka pada dokumen ini diverifikasi dari dokumentasi resmi Firebase pada  
> **19 September 2026**. Kuota dan harga dapat berubah — periksa kembali di  
> [firebase.google.com/pricing](https://firebase.google.com/pricing) sebelum  
> mengambil keputusan jangka panjang.

---

## Daftar isi

1. [Apakah Blaze itu berbayar?](#bagian-a--apakah-blaze-itu-berbayar)
2. [Production mode vs Test mode](#bagian-b--production-mode-vs-test-mode)
3. [Batasan jika hanya memakai Firestore](#bagian-c--batasan-jika-hanya-memakai-firestore)
4. [Konsekuensi terhadap proyek ini](#bagian-d--konsekuensi-terhadap-proyek-ini)
5. [Langkah agar tetap Rp0](#bagian-e--langkah-agar-tetap-rp0)
6. [Perkiraan pemakaian proyek ini](#bagian-f--perkiraan-pemakaian-proyek-ini)

---

## Bagian A — Apakah Blaze itu berbayar?

**Blaze bukan "langganan berbayar".** Blaze adalah model *pay-as-you-go*: Anda  
memasang metode pembayaran, tetapi **tidak ditagih selama pemakaian berada di  
bawah kuota gratis**. Yang berubah saat naik ke Blaze hanyalah *apa yang terjadi  
kalau kuota terlampaui* — pada Spark layanan dimatikan, pada Blaze kelebihannya  
ditagih.

|                                                             | **Spark (gratis)**    | **Blaze (pay-as-you-go)** |
| ----------------------------------------------------------- | --------------------- | ------------------------- |
| Metode pembayaran                                           | Tidak perlu           | **Wajib** dipasang        |
| Produk tanpa biaya (Auth, FCM, Crashlytics, App Check)      | Penuh                 | Penuh                     |
| Kuota gratis Firestore                                      | ✅ Ada                 | ✅ Ada                     |
| ~~Kelebihan kuota~~                                         | Layanan **dimatikan** | **Ditagih**               |
| Cloud Functions                                             | ❌ **Tidak tersedia**  | ✅ Tersedia                |
| Cloud Storage (bucket baru)                                 | ❌ **Tidak tersedia**  | ✅ Tersedia                |
| Produk Google Cloud berbayar (Pub/Sub, Cloud Run, BigQuery) | ❌                     | ✅                         |

### Yang benar-benar butuh Blaze

Hanya dua hal yang dipakai proyek ini:

| Layanan                         | Spark | Catatan                                                                          |
| ------------------------------- | ----- | -------------------------------------------------------------------------------- |
| **Cloud Functions**             | ❌     | Tidak bisa di-deploy sama sekali di Spark                                        |
| **Cloud Storage**               | ❌     | Sejak perubahan September 2024, *bucket default baru* hanya bisa dibuat di Blaze |
| Cloud Firestore                 | ✅     | Bisa, dengan kuota gratis                                                        |
| Authentication (Email/Password) | ✅     | Produk tanpa biaya                                                               |
| Cloud Messaging (FCM)           | ✅     | Produk tanpa biaya, tanpa batas praktis                                          |

### Peringatan penting soal Blaze

Dokumentasi resmi menyatakan: bila proyek tetap dalam kuota gratis Blaze, **tidak  
akan ada tagihan — dengan satu pengecualian: Cloud Functions**. Pemakaian Cloud  
Functions dalam kuota gratis pun dapat menimbulkan biaya kecil (untuk resource  
Cloud Storage dan jaringan di baliknya).

Selain itu: **budget alert tidak membatasi pengeluaran.** Ia hanya mengirim  
notifikasi. Jadi "sudah pasang alert" bukan jaminan tidak ada tagihan.

**Kesimpulan:** kalau tujuan Anda adalah jaminan mutlak Rp0, **jangan naik ke  
Blaze sama sekali.** Tetap di Spark.

---

## Bagian B — Production mode vs Test mode

Ini sering disalahpahami. **Kedua mode menghasilkan database yang identik** —  
yang berbeda hanya *Security Rules awal* yang dipasang, dan keduanya bisa diubah  
kapan saja setelahnya.

|                     | **Test mode**                                              | **Production mode**                     |
| ------------------- | ---------------------------------------------------------- | --------------------------------------- |
| Rules awal          | `allow read, write: if request.time < timestamp.date(...)` | `allow read, write: if false`           |
| Akses awal          | **Terbuka untuk siapa saja**                               | Semua ditolak                           |
| Masa berlaku        | **Kedaluwarsa otomatis (default 30 hari)**                 | Tidak ada kedaluwarsa                   |
| Setelah kedaluwarsa | **Seluruh akses ditolak** — aplikasi berhenti total        | Tetap ditolak sampai Anda menulis rules |
| Cocok untuk         | Eksperimen 10 menit di laptop sendiri                      | Segalanya yang lain                     |

### Kenapa Test mode berbahaya

Selama 30 hari itu, siapa pun yang mengetahui `projectId` Anda dapat membaca  
**dan menulis** seluruh database — termasuk menghapus semua data — tanpa perlu  
login. `projectId` Anda (`fir-test-3168e`) bukan rahasia; nilainya tertanam di  
dalam APK yang bisa dibongkar siapa saja.

Dan setelah 30 hari, aturan itu berubah menjadi **menolak semuanya**. Aplikasi  
Anda akan tiba-tiba berhenti bekerja dengan galat `permission-denied` di semua  
layar, tanpa perubahan kode apa pun. Ini penyebab paling umum dari keluhan  
"aplikasi Firebase saya tiba-tiba rusak".

### Yang harus Anda pilih

**Production mode.** Lalu segera deploy rules yang sudah disiapkan di proyek ini:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Rules tersebut sudah dirancang untuk aplikasi ini — setiap koleksi punya aturan  
eksplisit, peran diambil dari dokumen `users/{uid}.jabatan` (bukan dari klien),  
dan ada aturan default `allow read, write: if false` di bagian akhir.

---

## Bagian C — Batasan jika hanya memakai Firestore

Kuota gratis Spark untuk Cloud Firestore (reset **setiap hari**, sekitar pukul  
**14:00 WIB** / tengah malam waktu Pasifik):

| Sumber daya          | Kuota gratis       | Sifat   |
| -------------------- | ------------------ | ------- |
| Pembacaan dokumen    | **50.000 / hari**  | Harian  |
| Penulisan dokumen    | **20.000 / hari**  | Harian  |
| Penghapusan dokumen  | **20.000 / hari**  | Harian  |
| Data tersimpan       | **1 GiB**          | Total   |
| Transfer data keluar | **10 GiB / bulan** | Bulanan |

Batasan tambahan:

- **Hanya satu database gratis per project.** Membuat database kedua (mis. untuk  
  staging) memerlukan billing.
- **Ukuran maksimum satu dokumen: 1 MiB.** Ini membatasi seberapa besar data yang  
  bisa dititipkan ke Firestore.
- **Fitur berikut butuh billing** dan tidak mendapat kuota gratis sama sekali:  
  TTL deletes, Point-in-Time Recovery, backup, restore, dan clone.

### Apa yang terjadi kalau kuota harian habis

Pada Spark, operasi Firestore **ditolak** sampai kuota harian berikutnya. Tidak  
ada tagihan — karena tidak ada metode pembayaran yang terpasang. Aplikasi akan  
menampilkan galat sampai reset berikutnya.

Ini sebenarnya **perilaku yang aman** untuk tujuan Anda: mustahil terjadi tagihan  
tak terduga. Konsekuensinya hanya gangguan sementara.

---

## Bagian D — Konsekuensi terhadap proyek ini

Inilah bagian yang paling penting untuk Anda ketahui.

### Yang tetap berjalan di Spark ✅

| Fitur                           | Status                             |
| ------------------------------- | ---------------------------------- |
| Registrasi & login NIM/NIDN     | ✅                                  |
| Kalender ketersediaan real-time | ✅                                  |
| Input/ubah/hapus jadwal lab     | ✅                                  |
| Formulir pengajuan reservasi    | ✅                                  |
| Verifikasi Setujui/Tolak        | ✅                                  |
| Pembatalan oleh pemohon         | ✅                                  |
| Push notification dua arah      | ✅ (FCM gratis tanpa batas praktis) |
| Kelola laboratorium             | ✅                                  |
| Security Rules & index          | ✅ (deploy rules tidak butuh Blaze) |

### Yang tadinya hilang di Spark — dan sudah diatasi ❌➜✅

Cloud Functions tidak bisa di-deploy di Spark. Itu berarti `submitBooking`,
`reviewBooking`, `onBookingCreated`, dan `onBookingReviewed` tidak aktif.

Dua di antaranya berdampak nyata:

| | Dampak | Status |
|---|--------|--------|
| **Validasi bentrok di server** | Hilang | ✅ **Sudah diatasi** lewat kunci keterisian slot |
| **Notifikasi otomatis** | Hilang | ⚠️ Belum diatasi — lihat di bawah |

#### Validasi bentrok: sudah aman di Spark

Semula jalur klien **tidak** bebas *race condition*, karena Firebase SDK Flutter
hanya mengizinkan `Transaction.get` pada `DocumentReference`, bukan `Query`.

Masalah itu sudah diselesaikan dengan **kunci keterisian slot**
([`ARSITEKTUR.md`](ARSITEKTUR.md#concurrency-control)): seluruh keterisian satu
laboratorium pada satu tanggal disimpan dalam **satu dokumen** `slot_locks`, dan
pemeriksaan bentrok menjadi pembacaan dokumen biasa di dalam transaksi.

Hasilnya: **anti-*double booking* yang benar-benar aman, tetap di Spark, tetap Rp0.**
Biayanya satu pembacaan dan satu penulisan tambahan per pengajuan — jauh di bawah
kuota.

#### Notifikasi otomatis: ini yang benar-benar hilang

Tanpa Cloud Functions, tidak ada yang mengirim notifikasi saat pengajuan dibuat
atau diverifikasi. Yang **masih** berjalan:

- Channel Android dan notifikasi in-app tetap dibuat (`flutter_local_notifications`)
- Ketukan notifikasi tetap mengarahkan ke daftar pengajuan sesuai peran
- Tetapi **tidak ada pesan yang datang**, karena tidak ada pengirim

Ini konsekuensi yang harus diterima di jalur Spark. Untuk tugas kuliah biasanya
tidak masalah — status pengajuan tetap terlihat di tab Pengajuan dan Verifikasi
secara real-time, hanya tanpa pemberitahuan.

### Ringkasan jalur

| | **Spark — Rp0 dijamin** | **Blaze — Rp0 selama dalam kuota** |
|---|---|---|
| Biaya | Nol, tanpa metode pembayaran | Kecil, dan Cloud Functions bisa menagih meski dalam kuota |
| Validasi bentrok | ✅ Aman (kunci slot) | ✅ Aman (kunci slot) |
| Notifikasi otomatis | ❌ Tidak ada | ✅ Ada |
| Cloud Storage (upload berkas) | ❌ | ✅ |
| Firestore, Auth, FCM | ✅ | ✅ |
| Perlu perubahan kode | Tidak | Ubah 1 baris `useCloudFunctionsForBooking` |

Karena kedua jalur memakai mekanisme kunci slot yang sama, berpindah dari Spark
ke Blaze (atau sebaliknya) tidak mengubah perilaku validasi apa pun. Yang berubah
hanya ada atau tidaknya notifikasi otomatis.


## Bagian E — Langkah agar tetap Rp0


### Wajib

1. **Jangan upgrade ke Blaze.** Cukup di Spark.  
   Sudah terlanjur naik? Buka *Project settings → Usage and billing → Details &  
   settings → Unlink billing account*. Proyek otomatis turun ke Spark.  
   (Catatan: semua Cloud Functions akan berhenti dan tidak bisa di-deploy ulang  
   selama di Spark.)
2. **Deploy hanya rules dan index** — jangan sertakan functions atau storage:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   **Jangan** menjalankan `firebase deploy --only functions` atau  
   `firebase deploy --only storage` — keduanya akan gagal di Spark.
3. **Pastikan `useCloudFunctionsForBooking` tetap `false`** di  
   `lib/core/config/app_config.dart`. Nilainya sudah `false` sejak awal.
4. **Pilih Production mode**, lalu langsung deploy rules dari proyek ini.  
   Jangan pakai Test mode — lihat [Bagian B](#bagian-b--production-mode-vs-test-mode).
5. **Jangan pasang metode pembayaran** ke project ini. Ini jaminan tunggal yang  
   paling kuat: tanpa metode pembayaran, tidak mungkin ada tagihan.

### Pantau pemakaian

1. **Cek berkala:** Firebase Console → ⚙ *Project settings* → tab *Usage and billing*  
   → lihat grafik *Firestore* per hari. Bandingkan dengan batas 50.000 baca dan  
   20.000 tulis.
2. **Kalau sudah mendekati batas**, tunggu reset harian (sekitar 14:00 WIB). Tidak  
   ada tindakan lain yang diperlukan.

### Rancang agar hemat kuota

1. **Sudah diterapkan di proyek ini** — kalender membaca data **per bulan**, bukan  
   per hari. Berpindah tanggal tidak memicu pembacaan baru sama sekali.  
   Nama laboratorium juga di-cache di provider, sehingga daftar pengajuan tidak  
   memicu pembacaan tambahan per baris.
2. **Hindari membuka kalender berulang kali dalam waktu singkat.** Setiap kali  
   layar kalender dibuka dari nol, seluruh jadwal bulan tersebut dibaca ulang.
3. **Index tidak menambah biaya tulis.** Menurut dokumentasi harga Firestore,  
   setiap `set`/`update` dihitung **satu write**; composite index hanya menambah  
   ukuran penyimpanan (masuk hitungan 1 GiB), bukan jumlah operasi tulis. Jadi  
   8 composite index di proyek ini tidak memotong kuota tulis Anda.
4. **Hapus index yang tidak terpakai.** Setiap index menambah penyimpanan dan  
   memperlambat penulisan. Index di `firestore.indexes.json` semuanya punya  
   alasan — lihat komentar pada query di repository.

---


## Bagian F — Perkiraan pemakaian proyek ini

Perhitungan kasar untuk satu kali membuka aplikasi dan menjelajah kalender:

| Aksi                                   | Pembacaan |
| -------------------------------------- | --------- |
| Muat daftar laboratorium               | 5         |
| Buka kalender bulan ini (jadwal acuan) | ~60       |
| Buka kalender bulan ini (pengajuan)    | ~30       |
| Buka tab Pengajuan saya                | ~10       |
| **Total per sesi**                     | **~105**  |

Dengan kuota 50.000 baca/hari, itu setara **±475 sesi per hari** — jauh lebih  
banyak daripada kebutuhan demo atau pengujian tugas.

| Sumber daya | Kuota/hari | Perkiraan pemakaian            | Sisa |
| ----------- | ---------- | ------------------------------ | ---- |
| Pembacaan   | 50.000     | ~105 / sesi                    | Aman |
| Penulisan   | 20.000     | ~2 / pengajuan                 | Aman |
| Penyimpanan | 1 GiB      | < 5 MB untuk ratusan pengajuan | Aman |

**Kesimpulan:** untuk keperluan tugas, kuota gratis Spark sangat longgar. Yang  
perlu Anda sadari bukan soal kuota, melainkan **hilangnya validasi bentrok di  
sisi server** — dan itu bisa diatasi lewat Jalur C di  
[Bagian D](#bagian-d--konsekuensi-terhadap-proyek-ini).

---

## Rujukan

- [Firebase Pricing Plans (Spark vs Blaze)](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
- [Cloud Firestore Quotas and Limits](https://firebase.google.com/docs/firestore/quotas)
- [Cloud Firestore Pricing](https://firebase.google.com/docs/firestore/pricing)
- [Perubahan Cloud Storage September 2024](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)
- [`CHECKLIST-SETUP.md`](CHECKLIST-SETUP.md) — langkah setup dengan pilihan jalur gratis
- [`ARSITEKTUR.md`](ARSITEKTUR.md) — penjelasan teknis concurrency control
