import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging, Message } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import {
  onDocumentCreated,
  onDocumentUpdated,
} from 'firebase-functions/v2/firestore';

import {
  BookingDocument,
  CHANNEL_ID,
  COLLECTION_BOOKINGS,
  COLLECTION_USERS,
  F,
  STATUS_DISETUJUI,
  STATUS_DITOLAK,
  TOPIC_KEPALA_LAB,
  UserDocument,
} from './constants';
import { formatRentangJam, formatTanggalPanjang } from './utils';

const db = getFirestore();

/**
 * Notifikasi push untuk alur pengajuan.
 *
 * Dua arah sesuai kebutuhan fungsional pada dokumen tugas:
 *  - pengajuan baru  -> Kepala Laboratorium,
 *  - status berubah  -> pemohon (Mahasiswa/Dosen).
 *
 * Catatan Android: payload menyetel `channelId` ke `CHANNEL_ID`. Channel
 * tersebut dibuat oleh aplikasi saat pertama dijalankan
 * (`NotificationService.initializeLocalNotifications`). Bila channel belum ada,
 * Android 8+ akan membuang notifikasi — jadi urutan pemasangan aplikasi lalu
 * login sangat menentukan.
 */

// =============================================================================
// Pengajuan baru -> Kepala Laboratorium
// =============================================================================

export const onBookingCreated = onDocumentCreated(
  `${COLLECTION_BOOKINGS}/{bookingId}`,
  async (event) => {
    const booking = event.data?.data() as BookingDocument | undefined;
    if (!booking) return;

    const bookingId = event.params.bookingId;

    const pesan: Message = {
      topic: TOPIC_KEPALA_LAB,
      notification: {
        title: 'Pengajuan kelas pengganti baru',
        body:
          `${booking.mata_kuliah} · ${formatTanggalPanjang(booking.tanggal)} · ` +
          `${formatRentangJam(booking.jam_mulai, booking.jam_selesai)}`,
      },
      data: {
        tipe: 'pengajuan_baru',
        id_booking: bookingId,
        id_lab: booking.id_lab,
        status: booking.status,
        nama_pemohon: booking.nama_pemohon ?? '-',
      },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: CHANNEL_ID },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    };

    try {
      await getMessaging().send(pesan);
      logger.info('Notifikasi pengajuan baru terkirim', {
        bookingId,
        topic: TOPIC_KEPALA_LAB,
      });
    } catch (error) {
      // Kegagalan notifikasi tidak boleh membuat pembuatan pengajuan gagal.
      logger.error('Gagal mengirim notifikasi pengajuan baru', {
        bookingId,
        error,
      });
    }
  },
);

// =============================================================================
// Status berubah -> pemohon
// =============================================================================

export const onBookingReviewed = onDocumentUpdated(
  `${COLLECTION_BOOKINGS}/{bookingId}`,
  async (event) => {
    const before = event.data?.before.data() as BookingDocument | undefined;
    const after = event.data?.after.data() as BookingDocument | undefined;
    if (!before || !after) return;

    // Hanya bertindak ketika status benar-benar berubah ke hasil verifikasi.
    if (before.status === after.status) return;
    if (after.status !== STATUS_DISETUJUI && after.status !== STATUS_DITOLAK) {
      return;
    }

    const bookingId = event.params.bookingId;
    const disetujui = after.status === STATUS_DISETUJUI;

    const profilSnap = await db
      .collection(COLLECTION_USERS)
      .doc(after.id_user)
      .get();

    const token = (profilSnap.data() as UserDocument | undefined)?.fcm_token;
    if (!token) {
      logger.info('Pemohon belum memiliki token FCM — notifikasi dilewati', {
        bookingId,
        uid: after.id_user,
      });
      return;
    }

    const judul = disetujui
      ? 'Pengajuan disetujui'
      : 'Pengajuan ditolak';

    const isi = disetujui
      ? `${after.mata_kuliah} · ${formatTanggalPanjang(after.tanggal)} · ` +
        `${formatRentangJam(after.jam_mulai, after.jam_selesai)}`
      : `${after.mata_kuliah} ditolak.` +
        (after.alasan_penolakan ? ` Alasan: ${after.alasan_penolakan}` : '');

    const pesan: Message = {
      token,
      notification: { title: judul, body: isi },
      data: {
        tipe: disetujui ? 'pengajuan_disetujui' : 'pengajuan_ditolak',
        id_booking: bookingId,
        id_lab: after.id_lab,
        status: after.status,
      },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: CHANNEL_ID },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    };

    try {
      await getMessaging().send(pesan);
      logger.info('Notifikasi status terkirim ke pemohon', {
        bookingId,
        uid: after.id_user,
        status: after.status,
      });
    } catch (error) {
      // Token bisa sudah kedaluwarsa (aplikasi dihapus / token direset).
      // Bersihkan agar tidak dicoba lagi pada pengajuan berikutnya.
      const kode = (error as { code?: string }).code;
      if (
        kode === 'messaging/registration-token-not-registered' ||
        kode === 'messaging/invalid-registration-token'
      ) {
        await db
          .collection(COLLECTION_USERS)
          .doc(after.id_user)
          .update({ [F.fcmToken]: null })
          .catch(() => undefined);
        logger.warn('Token FCM tidak valid — sudah dibersihkan', {
          uid: after.id_user,
        });
      } else {
        logger.error('Gagal mengirim notifikasi status', { bookingId, error });
      }
    }
  },
);
