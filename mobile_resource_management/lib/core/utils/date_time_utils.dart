import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utilitas tanggal & waktu.
///
/// Konvensi penyimpanan di Firestore (mengikuti semangat DDL `DATE` dan `TIME`):
/// * `tanggal`      -> `String` format `yyyy-MM-dd` (aman untuk query rentang)
/// * `jam_mulai`    -> `String` format `HH:mm`
/// * `jam_selesai`  -> `String` format `HH:mm`
/// * `mulai_menit`  -> `int` menit sejak tengah malam (mempermudah deteksi bentrok)
class DateTimeUtils {
  const DateTimeUtils._();

  static const String localeId = 'id_ID';
  static const String dateKeyPattern = 'yyyy-MM-dd';

  static const List<String> namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> namaBulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // ---------------------------------------------------------------------------
  // Tanggal
  // ---------------------------------------------------------------------------

  /// `DateTime` -> `'yyyy-MM-dd'` (kunci dokumen di Firestore).
  static String toDateKey(DateTime date) =>
      DateFormat(dateKeyPattern).format(date);

  /// `'yyyy-MM-dd'` -> `DateTime` (jam 00:00 waktu lokal).
  static DateTime parseDateKey(String dateKey) {
    final parsed = DateTime.tryParse(dateKey);
    if (parsed == null) {
      throw FormatException('Format tanggal tidak valid: $dateKey');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Membuang komponen jam/menit/detik.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  /// Hari ini tanpa komponen waktu.
  static DateTime get today => dateOnly(DateTime.now());

  static bool isPast(DateTime date) => dateOnly(date).isBefore(today);

  /// Nama hari dalam bahasa Indonesia (1 = Senin ... 7 = Minggu).
  static String namaHariDari(DateTime date) => namaHari[date.weekday - 1];

  /// Contoh: `Sabtu, 19 September 2026`.
  static String formatTanggalPanjang(DateTime date) {
    final hari = namaHariDari(date);
    final bulan = namaBulan[date.month - 1];
    return '$hari, ${date.day} $bulan ${date.year}';
  }

  /// Contoh: `19 Sep 2026`.
  static String formatTanggalPendek(DateTime date) {
    final bulan = namaBulan[date.month - 1].substring(0, 3);
    return '${date.day} $bulan ${date.year}';
  }

  /// Contoh: `19/09/2026`.
  static String formatTanggalAngka(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  // ---------------------------------------------------------------------------
  // Bulan
  // ---------------------------------------------------------------------------

  /// `DateTime` -> `'yyyy-MM'` (dipakai sebagai kunci provider per bulan).
  static String toMonthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  /// Hari pertama pada bulan yang ditunjuk `'yyyy-MM'`.
  static DateTime firstDayOfMonth(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length < 2) {
      throw FormatException('Format bulan tidak valid: $monthKey');
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      throw FormatException('Format bulan tidak valid: $monthKey');
    }
    return DateTime(year, month, 1);
  }

  /// Hari terakhir pada bulan yang ditunjuk `'yyyy-MM'`.
  static DateTime lastDayOfMonth(String monthKey) {
    final first = firstDayOfMonth(monthKey);
    return DateTime(first.year, first.month + 1, 0);
  }

  /// Contoh: `September 2026`.
  static String formatNamaBulan(DateTime date) =>
      '${namaBulan[date.month - 1]} ${date.year}';

  /// Bulan berikutnya / sebelumnya sebagai `'yyyy-MM'`.
  static String geserBulan(String monthKey, int delta) {
    final first = firstDayOfMonth(monthKey);
    return toMonthKey(DateTime(first.year, first.month + delta, 1));
  }

  /// Selisih hari kalender (positif bila [date] di masa depan).
  static int daysFromToday(DateTime date) =>
      dateOnly(date).difference(today).inDays;

  // ---------------------------------------------------------------------------
  // Jam
  // ---------------------------------------------------------------------------

  /// `TimeOfDay` -> `'HH:mm'`.
  static String toTimeKey(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// `'HH:mm'` -> `TimeOfDay`.
  static TimeOfDay parseTimeKey(String timeKey) {
    final parts = timeKey.split(':');
    if (parts.length < 2) {
      throw FormatException('Format jam tidak valid: $timeKey');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      throw FormatException('Format jam tidak valid: $timeKey');
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// `'HH:mm'` -> menit sejak tengah malam. Mengembalikan `-1` bila tidak valid.
  static int minutesFromTimeKey(String timeKey) {
    final parts = timeKey.split(':');
    if (parts.length < 2) return -1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return -1;
    return (hour * 60) + minute;
  }

  /// Menit sejak tengah malam -> `'HH:mm'`.
  static String timeKeyFromMinutes(int minutes) {
    final normalized = minutes.clamp(0, 24 * 60);
    final hour = (normalized ~/ 60) % 24;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// Contoh: `08:00 - 10:30` atau `08:00 – 10:30` bila [useEnDash].
  static String formatRentangJam(
    String jamMulai,
    String jamSelesai, {
    bool useEnDash = true,
  }) {
    return '$jamMulai ${useEnDash ? '–' : '-'} $jamSelesai';
  }

  /// Durasi sesi dalam menit.
  static int durasiMenit(String jamMulai, String jamSelesai) =>
      minutesFromTimeKey(jamSelesai) - minutesFromTimeKey(jamMulai);

  /// Contoh: `2 jam 30 menit`.
  static String formatDurasi(int totalMenit) {
    if (totalMenit <= 0) return '0 menit';
    final jam = totalMenit ~/ 60;
    final menit = totalMenit % 60;
    if (jam == 0) return '$menit menit';
    if (menit == 0) return '$jam jam';
    return '$jam jam $menit menit';
  }

  // ---------------------------------------------------------------------------
  // Deteksi bentrok jadwal
  // ---------------------------------------------------------------------------

  /// Dua rentang waktu [aMulai, aSelesai) dan [bMulai, bSelesai) dinyatakan
  /// bentrok bila irisan keduanya lebih dari nol menit.
  ///
  /// Rumus: `aMulai < bSelesai && bMulai < aSelesai`
  ///
  /// Contoh: 08:00–10:00 dan 10:00–12:00 **tidak** bentrok (bersinggungan saja).
  static bool isRentangBentrok({
    required int aMulai,
    required int aSelesai,
    required int bMulai,
    required int bSelesai,
  }) {
    return aMulai < bSelesai && bMulai < aSelesai;
  }

  /// Membangkitkan pilihan jam pada rentang operasional laboratorium.
  ///
  /// Contoh (08:00-12:00, langkah 30 menit):
  /// `[08:00, 08:30, 09:00, ..., 11:30]`
  static List<TimeOfDay> generateSlotTimes({
    required int startHour,
    required int endHour,
    int stepMinutes = 30,
  }) {
    final slots = <TimeOfDay>[];
    final totalMenit = (endHour - startHour) * 60;
    for (var offset = 0; offset < totalMenit; offset += stepMinutes) {
      slots.add(
        TimeOfDay(
          hour: startHour + (offset ~/ 60),
          minute: offset % 60,
        ),
      );
    }
    return slots;
  }
}
