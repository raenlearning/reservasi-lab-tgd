import { getFirestore, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  BookingDocument,
  COLLECTION_BOOKINGS,
  COLLECTION_LABS,
  COLLECTION_LAB_SCHEDULES,
  COLLECTION_SLOT_LOCKS,
  COLLECTION_USERS,
  F,
  LabScheduleDocument,
  ROLE_KEPALA_LAB,
  STATUS_DISETUJUI,
  STATUS_DITOLAK,
  STATUS_MENUNGGU,
  UserDocument,
} from "./constants";
import {
  acquireSlots,
  findSlotConflict,
  formatRentangJam,
  formatTanggalPanjang,
  isValidDateKey,
  isValidTimeKey,
  labelSlot,
  minutesFromTimeKey,
  readSlots,
  slotLockDocId,
  slotOwnerBooking,
  validateBookingDate,
  validateTimeRange,
} from "./utils";

const db = getFirestore();

// =============================================================================
// Kunci keterisian slot
// =============================================================================

/**
 * Membaca keterisian slot dan memastikan rentang waktu masih bebas.
 *
 * Seluruh informasi keterisian satu laboratorium pada satu tanggal disimpan
 * dalam **satu dokumen**, sehingga pemeriksaan hanya perlu satu pembacaan.
 * Dokumen itulah yang menjadi titik serialisasi transaksi: dua operasi yang
 * menyentuh dokumen yang sama akan terdeteksi Firestore sebagai konflik, dan
 * yang kalah dijalankan ulang.
 *
 * Mengembalikan peta `slots` yang sudah dibaca, supaya pemanggil dapat
 * menulisnya kembali tanpa membaca ulang.
 */
async function assertSlotsFree(
  transaction: Transaction,
  {
    idLab,
    tanggal,
    mulaiMenit,
    selesaiMenit,
    idPengecualian,
  }: {
    idLab: string;
    tanggal: string;
    mulaiMenit: number;
    selesaiMenit: number;
    idPengecualian?: string;
  },
): Promise<Record<string, string>> {
  const ref = db
    .collection(COLLECTION_SLOT_LOCKS)
    .doc(slotLockDocId(idLab, tanggal));

  const snapshot = await transaction.get(ref);
  const slots = readSlots(snapshot.data());

  const bentrok = findSlotConflict(
    slots,
    mulaiMenit,
    selesaiMenit,
    idPengecualian,
  );
  if (bentrok === null) return slots;

  throw new HttpsError("aborted", await describeConflict(transaction, bentrok));
}

/** Menulis kembali peta keterisian slot. */
function writeSlots(
  transaction: Transaction,
  {
    idLab,
    tanggal,
    slots,
  }: { idLab: string; tanggal: string; slots: Record<string, string> },
): void {
  transaction.set(
    db.collection(COLLECTION_SLOT_LOCKS).doc(slotLockDocId(idLab, tanggal)),
    { id_lab: idLab, tanggal, slots, updated_at: new Date() },
  );
}

/**
 * Menyusun pesan bentrok yang menyebut **apa** yang menempati slot tersebut.
 *
 * Detail pemilik dibaca dari dokumennya, dan hanya pada jalur kesalahan —
 * sehingga tidak menambah biaya pada kasus normal.
 */
async function describeConflict(
  transaction: Transaction,
  bentrok: { indeksSlot: number; pemilik: string },
): Promise<string> {
  const prefiks = bentrok.pemilik.slice(0, 1);
  const id = bentrok.pemilik.slice(2);

  try {
    if (prefiks === "b") {
      const snapshot = await transaction.get(
        db.collection(COLLECTION_BOOKINGS).doc(id),
      );
      const data = snapshot.data() as BookingDocument | undefined;
      if (data !== undefined) {
        const pemohon = data.nama_pemohon ? ` oleh ${data.nama_pemohon}` : "";
        return (
          `Jadwal bentrok dengan kelas pengganti ${data.mata_kuliah}${pemohon} ` +
          `pada ${formatRentangJam(data.jam_mulai, data.jam_selesai)}. ` +
          `Silakan pilih slot waktu lain.`
        );
      }
    } else if (prefiks === "s") {
      const snapshot = await transaction.get(
        db.collection(COLLECTION_LAB_SCHEDULES).doc(id),
      );
      const data = snapshot.data() as LabScheduleDocument | undefined;
      if (data !== undefined) {
        const dosen = data.nama_dosen ? ` (${data.nama_dosen})` : "";
        return (
          `Jadwal bentrok dengan ${data.tipe.toLowerCase()} ` +
          `${data.mata_kuliah}${dosen} pada ` +
          `${formatRentangJam(data.jam_mulai, data.jam_selesai)}.`
        );
      }
    }
  } catch {
    // Detail pemilik tidak terbaca — jatuh ke pesan generik di bawah.
  }

  return (
    `Slot ${labelSlot(bentrok.indeksSlot)} sudah terpakai. ` +
    `Silakan pilih waktu lain.`
  );
}

// =============================================================================
// submitBooking — pengajuan reservasi kelas pengganti
// =============================================================================

interface SubmitBookingRequest {
  id_lab?: unknown;
  mata_kuliah?: unknown;
  tanggal?: unknown;
  jam_mulai?: unknown;
  jam_selesai?: unknown;
  catatan?: unknown;
}

interface SubmitBookingResponse {
  id_booking: string;
  status: string;
}

/**
 * Membuat pengajuan reservasi baru.
 *
 * Inilah implementasi *concurrency control* yang diamanatkan dokumen tugas.
 * Pemeriksaan jadwal bentrok dijalankan **di dalam transaksi Firestore** lewat
 * kunci keterisian slot, sehingga dua pengajuan yang dikirim bersamaan tidak
 * mungkin sama-sama lolos.
 *
 * Pendekatan kunci slot dipilih (bukan query biasa) agar **jalur server dan
 * jalur klien memakai mekanisme yang identik**. Jalur klien perlu itu karena
 * Firebase SDK Flutter hanya mengizinkan `Transaction.get` pada
 * `DocumentReference`, bukan `Query`. Dengan satu mekanisme, berpindah antara
 * paket Spark dan Blaze tidak mengubah perilaku apa pun.
 *
 * Langkah:
 *   1. Validasi bentuk & aturan waktu (jam operasional, durasi, horizon hari).
 *   2. Ambil profil pemohon untuk denormalisasi nama & NIM/NIDN.
 *   3. Transaksi:
 *      a. pastikan laboratorium ada,
 *      b. baca keterisian slot hari itu,
 *      c. tolak bila ada irisan waktu,
 *      d. tulis dokumen `bookings` berstatus `Menunggu`.
 *
 * Slot **tidak** dikunci pada tahap ini: beberapa pemohon boleh mengajukan
 * waktu yang sama, dan Kepala Laboratorium yang memutuskan. Penguncian terjadi
 * di [reviewBooking].
 */
export const submitBooking = onCall<SubmitBookingRequest>(
  { enforceAppCheck: false, cors: true },
  async (request): Promise<SubmitBookingResponse> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Anda belum masuk ke aplikasi.");
    }

    const data = request.data ?? {};
    const idLab = data.id_lab;
    const mataKuliah = data.mata_kuliah;
    const tanggal = data.tanggal;
    const jamMulai = data.jam_mulai;
    const jamSelesai = data.jam_selesai;
    const catatan =
      typeof data.catatan === "string" ? data.catatan.trim() : undefined;

    // --- 1. Validasi bentuk input ------------------------------------------
    if (typeof idLab !== "string" || idLab.length === 0) {
      throw new HttpsError("invalid-argument", "Laboratorium wajib dipilih.");
    }
    if (typeof mataKuliah !== "string" || mataKuliah.trim().length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Nama mata kuliah minimal 3 karakter.",
      );
    }
    if (mataKuliah.trim().length > 100) {
      throw new HttpsError(
        "invalid-argument",
        "Nama mata kuliah maksimal 100 karakter.",
      );
    }
    if (!isValidDateKey(tanggal)) {
      throw new HttpsError("invalid-argument", "Format tanggal tidak valid.");
    }
    if (!isValidTimeKey(jamMulai) || !isValidTimeKey(jamSelesai)) {
      throw new HttpsError("invalid-argument", "Format jam tidak valid.");
    }

    const mulaiMenit = minutesFromTimeKey(jamMulai);
    const selesaiMenit = minutesFromTimeKey(jamSelesai);

    const pesanWaktu = validateTimeRange(mulaiMenit, selesaiMenit);
    if (pesanWaktu) throw new HttpsError("invalid-argument", pesanWaktu);

    const pesanTanggal = validateBookingDate(tanggal);
    if (pesanTanggal) throw new HttpsError("invalid-argument", pesanTanggal);

    // --- 2. Profil pemohon --------------------------------------------------
    const profileSnap = await db.collection(COLLECTION_USERS).doc(uid).get();
    if (!profileSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Profil pengguna tidak ditemukan. Hubungi administrator.",
      );
    }
    const profil = profileSnap.data() as UserDocument;
    if (profil.is_active === false) {
      throw new HttpsError(
        "permission-denied",
        "Akun Anda dinonaktifkan. Hubungi Kepala Laboratorium.",
      );
    }

    // --- 3. Transaksi: periksa keterisian slot lalu tulis -------------------
    const bookingId = await db.runTransaction(async (transaction) => {
      const labSnap = await transaction.get(
        db.collection(COLLECTION_LABS).doc(idLab),
      );
      if (!labSnap.exists) {
        throw new HttpsError("not-found", "Laboratorium tidak ditemukan.");
      }

      await assertSlotsFree(transaction, {
        idLab,
        tanggal,
        mulaiMenit,
        selesaiMenit,
      });

      const bookingRef = db.collection(COLLECTION_BOOKINGS).doc();
      transaction.set(bookingRef, {
        [F.idUser]: uid,
        [F.idLab]: idLab,
        [F.mataKuliah]: mataKuliah.trim(),
        [F.tanggal]: tanggal,
        [F.jamMulai]: jamMulai,
        [F.jamSelesai]: jamSelesai,
        [F.mulaiMenit]: mulaiMenit,
        [F.selesaiMenit]: selesaiMenit,
        [F.status]: STATUS_MENUNGGU,
        [F.namaPemohon]: profil.nama,
        [F.nomorIdentitasPemohon]: profil.nomor_identitas,
        ...(catatan ? { [F.catatan]: catatan } : {}),
        [F.createdAt]: new Date(),
        [F.updatedAt]: new Date(),
      });

      logger.info("Pengajuan reservasi dibuat", {
        bookingId: bookingRef.id,
        uid,
        idLab,
        tanggal,
        mulaiMenit,
        selesaiMenit,
      });

      return bookingRef.id;
    });

    return { id_booking: bookingId, status: STATUS_MENUNGGU };
  },
);

// =============================================================================
// reviewBooking — persetujuan / penolakan oleh Kepala Laboratorium
// =============================================================================

interface ReviewBookingRequest {
  id_booking?: unknown;
  disetujui?: unknown;
  alasan_penolakan?: unknown;
}

interface ReviewBookingResponse {
  id_booking: string;
  status: string;
}

/**
 * Menyetujui atau menolak pengajuan.
 *
 * Verifikasi peran dilakukan di server (bukan hanya di klien). Saat menyetujui,
 * slot pada rentang waktu tersebut **dikunci di dalam transaksi yang sama**
 * dengan perubahan status, sehingga dua persetujuan tidak mungkin menghasilkan
 * jadwal ganda.
 */
export const reviewBooking = onCall<ReviewBookingRequest>(
  { enforceAppCheck: false, cors: true },
  async (request): Promise<ReviewBookingResponse> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Anda belum masuk ke aplikasi.");
    }

    const data = request.data ?? {};
    const bookingId = data.id_booking;
    const disetujui = data.disetujui;
    const alasan =
      typeof data.alasan_penolakan === "string"
        ? data.alasan_penolakan.trim()
        : "";

    if (typeof bookingId !== "string" || bookingId.length === 0) {
      throw new HttpsError("invalid-argument", "ID pengajuan wajib diisi.");
    }
    if (typeof disetujui !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "Keputusan verifikasi wajib diisi.",
      );
    }
    if (!disetujui && alasan.length === 0) {
      throw new HttpsError("invalid-argument", "Alasan penolakan wajib diisi.");
    }

    // --- Verifikasi peran ---------------------------------------------------
    const reviewerSnap = await db.collection(COLLECTION_USERS).doc(uid).get();
    const reviewer = reviewerSnap.data() as UserDocument | undefined;
    if (!reviewerSnap.exists || reviewer?.jabatan !== ROLE_KEPALA_LAB) {
      throw new HttpsError(
        "permission-denied",
        "Hanya Kepala Laboratorium yang dapat memverifikasi pengajuan.",
      );
    }

    // --- Transaksi ----------------------------------------------------------
    const statusBaru = await db.runTransaction(async (transaction) => {
      const bookingRef = db.collection(COLLECTION_BOOKINGS).doc(bookingId);
      const bookingSnap = await transaction.get(bookingRef);

      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Pengajuan tidak ditemukan.");
      }

      const booking = bookingSnap.data() as BookingDocument;
      if (booking.status !== STATUS_MENUNGGU) {
        throw new HttpsError(
          "failed-precondition",
          "Pengajuan ini sudah pernah diverifikasi.",
        );
      }

      if (disetujui) {
        const slots = await assertSlotsFree(transaction, {
          idLab: booking.id_lab,
          tanggal: booking.tanggal,
          mulaiMenit: booking.mulai_menit,
          selesaiMenit: booking.selesai_menit,
        });

        writeSlots(transaction, {
          idLab: booking.id_lab,
          tanggal: booking.tanggal,
          slots: acquireSlots(
            slots,
            booking.mulai_menit,
            booking.selesai_menit,
            slotOwnerBooking(bookingId),
          ),
        });
      }

      const status = disetujui ? STATUS_DISETUJUI : STATUS_DITOLAK;

      transaction.update(bookingRef, {
        [F.status]: status,
        [F.diverifikasiOleh]: uid,
        [F.diverifikasiPada]: new Date(),
        [F.alasanPenolakan]: disetujui ? null : alasan,
        [F.updatedAt]: new Date(),
      });

      logger.info("Pengajuan diverifikasi", {
        bookingId,
        reviewer: uid,
        status,
        tanggal: booking.tanggal,
      });

      return status;
    });

    return { id_booking: bookingId, status: statusBaru };
  },
);

// =============================================================================
// Utilitas internal (dipakai pengujian / emulator)
// =============================================================================

/**
 * Ringkasan pengajuan untuk keperluan log — tidak dipakai di jalur produksi.
 */
export function ringkasPengajuan(booking: BookingDocument): string {
  return (
    `${booking.mata_kuliah} · ${formatTanggalPanjang(booking.tanggal)} · ` +
    `${formatRentangJam(booking.jam_mulai, booking.jam_selesai)} · ` +
    `${booking.status}`
  );
}
