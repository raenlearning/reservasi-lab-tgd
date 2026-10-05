import { Timestamp } from 'firebase-admin/firestore';

import {
  F,
  HORIZON_HARI,
  MAKS_DURASI_MENIT,
  OPERASIONAL_MULAI_MENIT,
  OPERASIONAL_SELESAI_MENIT,
  SLOT_MENIT,
} from './constants';

/**
 * Utilitas waktu.
 *
 * Tanggal & jam disimpan sebagai string (`yyyy-MM-dd`, `HH:mm`) mengikuti
 * rancangan tabel `DATE`/`TIME` pada dokumen tugas, dengan tambahan kolom
 * `*_menit` (integer) agar deteksi bentrok tidak perlu mem-parsing string.
 */

const DATE_KEY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const TIME_KEY_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;

export function isValidDateKey(value: unknown): value is string {
  if (typeof value !== 'string' || !DATE_KEY_PATTERN.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime());
}

export function isValidTimeKey(value: unknown): value is string {
  return typeof value === 'string' && TIME_KEY_PATTERN.test(value);
}

/** `'HH:mm'` -> menit sejak tengah malam. */
export function minutesFromTimeKey(timeKey: string): number {
  const [hour, minute] = timeKey.split(':').map(Number);
  return hour * 60 + minute;
}

/** Menit sejak tengah malam -> `'HH:mm'`. */
export function timeKeyFromMinutes(minutes: number): string {
  const hour = Math.floor(minutes / 60) % 24;
  const minute = minutes % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

/**
 * Dua rentang [aMulai, aSelesai) dan [bMulai, bSelesai) dinyatakan bentrok
 * bila irisannya lebih dari nol menit.
 *
 * Bersinggungan saja (10:00 selesai, 10:00 mulai) TIDAK dianggap bentrok.
 */
export function isOverlapping(
  aStart: number,
  aEnd: number,
  bStart: number,
  bEnd: number,
): boolean {
  return aStart < bEnd && bStart < aEnd;
}

/** Format `yyyy-MM-dd` untuk tanggal hari ini menurut zona waktu kampus. */
export function todayDateKey(timeZone = 'Asia/Jakarta'): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

/** Selisih hari kalender antara `dateKey` dan hari ini (positif = masa depan). */
export function daysFromToday(dateKey: string, timeZone = 'Asia/Jakarta'): number {
  const [year, month, day] = dateKey.split('-').map(Number);
  const target = Date.UTC(year, month - 1, day);

  const today = todayDateKey(timeZone);
  const [todayYear, todayMonth, todayDay] = today.split('-').map(Number);
  const base = Date.UTC(todayYear, todayMonth - 1, todayDay);

  return Math.round((target - base) / 86_400_000);
}

/** Format tanggal yang enak dibaca, mis. `Sabtu, 19 September 2026`. */
export function formatTanggalPanjang(dateKey: string): string {
  const [year, month, day] = dateKey.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  return new Intl.DateTimeFormat('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}

/** Rentang jam yang enak dibaca, mis. `08:00 – 10:30`. */
export function formatRentangJam(mulai: string, selesai: string): string {
  return `${mulai} – ${selesai}`;
}

/** Validasi rentang waktu terhadap jam operasional dan durasi maksimum. */
export function validateTimeRange(
  mulaiMenit: number,
  selesaiMenit: number,
): string | null {
  if (selesaiMenit <= mulaiMenit) {
    return 'Jam selesai harus lebih besar daripada jam mulai.';
  }
  if (selesaiMenit - mulaiMenit > MAKS_DURASI_MENIT) {
    const jam = MAKS_DURASI_MENIT / 60;
    return `Durasi sesi maksimal ${jam} jam.`;
  }
  if (
    mulaiMenit < OPERASIONAL_MULAI_MENIT ||
    selesaiMenit > OPERASIONAL_SELESAI_MENIT
  ) {
    return (
      'Jam yang dipilih di luar jam operasional laboratorium ' +
      `(${timeKeyFromMinutes(OPERASIONAL_MULAI_MENIT)} – ` +
      `${timeKeyFromMinutes(OPERASIONAL_SELESAI_MENIT)}).`
    );
  }
  return null;
}

/** Validasi tanggal pengajuan (tidak boleh masa lalu, tidak terlalu jauh). */
export function validateBookingDate(tanggal: string): string | null {
  const selisih = daysFromToday(tanggal);
  if (selisih < 0) {
    return 'Tanggal yang dipilih sudah lewat.';
  }
  if (selisih > HORIZON_HARI) {
    return `Pengajuan hanya dapat dilakukan maksimal ${HORIZON_HARI} hari ke depan.`;
  }
  return null;
}

export function serverTimestamp(): Timestamp {
  return Timestamp.now();
}

/** Helper penamaan field agar konsisten dengan sisi Flutter. */
export const Fields = F;

// =============================================================================
// Kunci keterisian slot
// =============================================================================

/** Document id pada koleksi `slot_locks`. */
export function slotLockDocId(idLab: string, tanggal: string): string {
  return `${idLab}_${tanggal}`;
}

/**
 * Seluruh indeks slot yang tercakup rentang `[mulaiMenit, selesaiMenit)`.
 *
 * Contoh dengan slot 30 menit:
 *  - 08:00-10:00 (480-600) -> [16, 17, 18, 19]
 *  - 10:00-12:00 (600-720) -> [20, 21, 22, 23]  (tidak bertabrakan)
 *  - rentang nol menit     -> []
 *
 * Sifat half-open dijaga oleh `selesaiMenit - 1`: batas akhir tidak ikut
 * terpakai, sehingga jadwal 08:00-10:00 dan 10:00-12:00 tidak dianggap bentrok.
 */
export function slotIndicesCovered(
  mulaiMenit: number,
  selesaiMenit: number,
): number[] {
  if (selesaiMenit <= mulaiMenit) return [];

  const pertama = Math.floor(mulaiMenit / SLOT_MENIT);
  const terakhir = Math.floor((selesaiMenit - 1) / SLOT_MENIT);

  const hasil: number[] = [];
  for (let indeks = pertama; indeks <= terakhir; indeks += 1) {
    hasil.push(indeks);
  }
  return hasil;
}

/** Label rentang waktu sebuah indeks slot, mis. `08:00 - 08:30`. */
export function labelSlot(indeksSlot: number): string {
  const mulai = timeKeyFromMinutes(indeksSlot * SLOT_MENIT);
  const selesai = timeKeyFromMinutes((indeksSlot + 1) * SLOT_MENIT);
  return `${mulai} - ${selesai}`;
}

/** Pemilik slot yang berasal dari pengajuan reservasi. */
export function slotOwnerBooking(idBooking: string): string {
  return `b:${idBooking}`;
}

/** Pemilik slot yang berasal dari jadwal acuan. */
export function slotOwnerSchedule(idSchedule: string): string {
  return `s:${idSchedule}`;
}

/**
 * Indeks slot pertama yang bertabrakan, atau `null` bila rentang bebas.
 *
 * [idPengecualian] dipakai saat mengubah entitas yang sudah memegang slot:
 * kepemilikannya sendiri tidak boleh dianggap bentrok.
 */
export function findSlotConflict(
  slots: Record<string, string>,
  mulaiMenit: number,
  selesaiMenit: number,
  idPengecualian?: string,
): { indeksSlot: number; pemilik: string } | null {
  for (const indeks of slotIndicesCovered(mulaiMenit, selesaiMenit)) {
    const pemilik = slots[String(indeks)];
    if (pemilik === undefined) continue;
    if (idPengecualian !== undefined && pemilik === idPengecualian) continue;
    return { indeksSlot: indeks, pemilik };
  }
  return null;
}

/** Menambahkan kepemilikan slot pada rentang tertentu. */
export function acquireSlots(
  slots: Record<string, string>,
  mulaiMenit: number,
  selesaiMenit: number,
  pemilik: string,
): Record<string, string> {
  const hasil = { ...slots };
  for (const indeks of slotIndicesCovered(mulaiMenit, selesaiMenit)) {
    hasil[String(indeks)] = pemilik;
  }
  return hasil;
}

/** Melepas seluruh slot yang dimiliki [pemilik]. */
export function releaseSlots(
  slots: Record<string, string>,
  pemilik: string,
): Record<string, string> {
  const hasil: Record<string, string> = {};
  for (const [indeks, value] of Object.entries(slots)) {
    if (value !== pemilik) hasil[indeks] = value;
  }
  return hasil;
}

/** Membaca peta `slots` dari data dokumen, dengan penanganan tipe defensif. */
export function readSlots(data: unknown): Record<string, string> {
  if (data === null || typeof data !== 'object') return {};
  const mentah = (data as { slots?: unknown }).slots;
  if (mentah === null || typeof mentah !== 'object') return {};

  const hasil: Record<string, string> = {};
  for (const [kunci, nilai] of Object.entries(mentah as object)) {
    hasil[kunci] = String(nilai);
  }
  return hasil;
}
