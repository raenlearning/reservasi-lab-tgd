import { Timestamp } from 'firebase-admin/firestore';

/**
 * Konstanta dan tipe bersama untuk Cloud Functions.
 *
 * Nilai di berkas ini HARUS sinkron dengan:
 *  - `lib/core/config/app_config.dart`        (sisi Flutter)
 *  - `lib/core/constants/firestore_paths.dart` (nama field)
 *  - `firestore.rules`                         (aturan validasi)
 */

// -----------------------------------------------------------------------------
// Nama koleksi
// -----------------------------------------------------------------------------

export const COLLECTION_USERS = 'users';
export const COLLECTION_LABS = 'labs';
export const COLLECTION_BOOKINGS = 'bookings';
export const COLLECTION_LAB_SCHEDULES = 'lab_schedules';

/**
 * Peta keterisian slot per laboratorium per hari.
 *
 * Koleksi ini adalah **titik serialisasi** yang membuat pemeriksaan jadwal
 * bentrok bebas race condition, baik di sisi klien (Firebase SDK Flutter tidak
 * mendukung query di dalam transaksi) maupun di sisi server. Lihat
 * `lib/data/models/lab_day_lock.dart` untuk penjelasan lengkapnya.
 *
 * HARUS selalu konsisten dengan koleksi `slot_locks` di `firestore.rules`.
 */
export const COLLECTION_SLOT_LOCKS = 'slot_locks';

// -----------------------------------------------------------------------------
// Enum domain (harus sama persis dengan nilai di Firestore)
// -----------------------------------------------------------------------------

export const ROLE_KEPALA_LAB = 'Kepala Lab';
export const ROLE_DOSEN = 'Dosen';
export const ROLE_MAHASISWA = 'Mahasiswa';

export const STATUS_MENUNGGU = 'Menunggu';
export const STATUS_DISETUJUI = 'Disetujui';
export const STATUS_DITOLAK = 'Ditolak';

export const TIPE_REGULER = 'Reguler';
export const TIPE_PENGGANTI = 'Pengganti';
export const TIPE_PEMELIHARAAN = 'Pemeliharaan';

/** Tipe jadwal yang memblokir slot agar tidak bisa diajukan. */
export const TIPE_PEMBLOKIR = [TIPE_REGULER, TIPE_PEMELIHARAAN];

// -----------------------------------------------------------------------------
// Aturan penjadwalan (sinkron dengan AppConfig)
// -----------------------------------------------------------------------------

/** Jam operasional laboratorium, dalam menit sejak tengah malam. */
export const OPERASIONAL_MULAI_MENIT = 8 * 60; // 08:00
export const OPERASIONAL_SELESAI_MENIT = 21 * 60; // 21:00

/** Durasi maksimum satu sesi kelas pengganti (menit). */
export const MAKS_DURASI_MENIT = 4 * 60;

/** Batas hari ke depan yang boleh diajukan. */
export const HORIZON_HARI = 60;

/**
 * Granularitas slot kunci keterisian (menit).
 *
 * HARUS sama dengan `AppConfig.slotMinutes` di `lib/core/config/app_config.dart`.
 * Mengubah nilai ini membuat seluruh dokumen `slot_locks` yang sudah ada tidak
 * lagi cocok dan harus dibangun ulang.
 */
export const SLOT_MENIT = 30;

// -----------------------------------------------------------------------------
// Nama field (snake_case, mengikuti rancangan tabel pada dokumen tugas)
// -----------------------------------------------------------------------------

export const F = {
  uid: 'uid',
  nomorIdentitas: 'nomor_identitas',
  nama: 'nama',
  jabatan: 'jabatan',
  fcmToken: 'fcm_token',
  isActive: 'is_active',

  namaLab: 'nama_lab',
  kapasitas: 'kapasitas',

  idUser: 'id_user',
  idLab: 'id_lab',
  mataKuliah: 'mata_kuliah',
  namaDosen: 'nama_dosen',
  tanggal: 'tanggal',
  jamMulai: 'jam_mulai',
  jamSelesai: 'jam_selesai',
  mulaiMenit: 'mulai_menit',
  selesaiMenit: 'selesai_menit',
  status: 'status',
  tipe: 'tipe',
  catatan: 'catatan',
  alasanPenolakan: 'alasan_penolakan',
  namaPemohon: 'nama_pemohon',
  nomorIdentitasPemohon: 'nomor_identitas_pemohon',
  diverifikasiOleh: 'diverifikasi_oleh',
  diverifikasiPada: 'diverifikasi_pada',
  dibuatOleh: 'dibuat_oleh',

  createdAt: 'created_at',
  updatedAt: 'updated_at',
} as const;

// -----------------------------------------------------------------------------
// Topik FCM
// -----------------------------------------------------------------------------

/** Topik yang diikuti seluruh Kepala Laboratorium. */
export const TOPIC_KEPALA_LAB = 'kepala_lab';

/**
 * Channel notifikasi Android.
 *
 * HARUS sama dengan `NotificationService.channelId` di sisi Flutter
 * (`lib/data/services/notification_service.dart`). Channel ini dibuat aplikasi
 * saat pertama dijalankan; bila belum ada, Android 8+ akan membuang notifikasi
 * yang menyetel channelId.
 */
export const CHANNEL_ID = 'mrm_high_importance';

// -----------------------------------------------------------------------------
// Bentuk dokumen
// -----------------------------------------------------------------------------

export interface BookingDocument {
  id_user: string;
  id_lab: string;
  mata_kuliah: string;
  tanggal: string;
  jam_mulai: string;
  jam_selesai: string;
  mulai_menit: number;
  selesai_menit: number;
  status: string;
  nama_pemohon?: string;
  nomor_identitas_pemohon?: string;
  catatan?: string;
  alasan_penolakan?: string | null;
  diverifikasi_oleh?: string;
  diverifikasi_pada?: Timestamp;
}

export interface LabScheduleDocument {
  id_lab: string;
  mata_kuliah: string;
  tanggal: string;
  jam_mulai: string;
  jam_selesai: string;
  mulai_menit: number;
  selesai_menit: number;
  tipe: string;
  nama_dosen?: string;
}

export interface UserDocument {
  uid: string;
  nomor_identitas: string;
  nama: string;
  email: string;
  jabatan: string;
  fcm_token?: string | null;
  is_active?: boolean;
}
