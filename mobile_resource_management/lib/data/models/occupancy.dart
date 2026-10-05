import '../../core/utils/date_time_utils.dart';
import 'booking.dart';
import 'enums.dart';
import 'lab_schedule.dart';

/// Satu blok waktu terpakai pada sebuah laboratorium.
///
/// Model ini menyatukan dua sumber data yang berbeda bentuk:
/// * [LabSchedule] — jadwal acuan yang diinput Kepala Laboratorium.
/// * [Booking]     — pengajuan kelas pengganti dari Mahasiswa/Dosen.
///
/// Dengan satu bentuk seragam, kalender ketersediaan dan pemeriksaan bentrok
/// cukup bekerja pada satu tipe data saja.
class OccupancySlot {
  const OccupancySlot({
    required this.id,
    required this.idLab,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.judul,
    required this.source,
    this.namaLab,
    this.subjudul,
    this.catatan,
  });

  final String id;
  final int idLab;
  final String? namaLab;

  /// `yyyy-MM-dd`.
  final String tanggal;

  /// `HH:mm`.
  final String jamMulai;

  /// `HH:mm`.
  final String jamSelesai;

  /// Mata kuliah / nama kegiatan.
  final String judul;

  /// Dosen pengampu atau nama pemohon.
  final String? subjudul;

  final OccupancySource source;
  final String? catatan;

  int get mulaiMenit => DateTimeUtils.minutesFromTimeKey(jamMulai);

  int get selesaiMenit => DateTimeUtils.minutesFromTimeKey(jamSelesai);

  int get durasiMenit => selesaiMenit - mulaiMenit;

  String get rentangJam => DateTimeUtils.formatRentangJam(jamMulai, jamSelesai);

  /// Slot ini menghalangi pengajuan baru pada rentang waktunya.
  bool get memblokirReservasi => source.blocksBooking;

  /// Tanggal slot sebagai [DateTime].
  ///
  /// Memakai `tryParse` supaya tanggal kosong atau rusak tidak melempar
  /// `FormatException`. 1 Januari 1970 menandai tanggal yang tidak diketahui.
  DateTime get tanggalDateTime =>
      DateTime.tryParse(tanggal) ?? DateTime(1970);

  bool bentrokDengan(OccupancySlot lain) {
    if (idLab != lain.idLab) return false;
    if (tanggal != lain.tanggal) return false;
    return DateTimeUtils.isRentangBentrok(
      aMulai: mulaiMenit,
      aSelesai: selesaiMenit,
      bMulai: lain.mulaiMenit,
      bSelesai: lain.selesaiMenit,
    );
  }

  /// Membangun slot dari jadwal acuan Kepala Lab.
  factory OccupancySlot.fromSchedule(LabSchedule schedule, {String? namaLab}) {
    return OccupancySlot(
      id: 'schedule:${schedule.id}',
      idLab: schedule.idLab,
      namaLab: namaLab,
      tanggal: schedule.tanggal,
      jamMulai: schedule.jamMulai,
      jamSelesai: schedule.jamSelesai,
      judul: schedule.mataKuliah,
      subjudul: schedule.namaDosen,
      catatan: schedule.catatan,
      source: switch (schedule.tipe) {
        ScheduleType.reguler => OccupancySource.jadwalReguler,
        ScheduleType.pengganti => OccupancySource.reservasiDisetujui,
        ScheduleType.pemeliharaan => OccupancySource.jadwalPemeliharaan,
      },
    );
  }

  /// Membangun slot dari pengajuan reservasi.
  ///
  /// Pengajuan berstatus `Menunggu` ikut ditampilkan (sebagai penanda
  /// "menunggu verifikasi") tetapi **tidak** memblokir pengajuan lain —
  /// lihat [OccupancySource.blocksBooking].
  factory OccupancySlot.fromBooking(Booking booking, {String? namaLab}) {
    return OccupancySlot(
      id: 'booking:${booking.id}',
      idLab: booking.idLab,
      namaLab: namaLab,
      tanggal: booking.tanggal,
      jamMulai: booking.jamMulai,
      jamSelesai: booking.jamSelesai,
      judul: booking.mataKuliah,
      subjudul: booking.namaPemohon,
      catatan: booking.catatan,
      source: booking.status.isDisetujui
          ? OccupancySource.reservasiDisetujui
          : OccupancySource.reservasiMenunggu,
    );
  }

  @override
  String toString() =>
      'OccupancySlot($idLab, $tanggal $rentangJam, ${source.label}, $judul)';
}

/// Rentang waktu sederhana (dipakai untuk daftar slot kosong).
class TimeRange {
  const TimeRange({required this.mulaiMenit, required this.selesaiMenit});

  final int mulaiMenit;
  final int selesaiMenit;

  String get jamMulai => DateTimeUtils.timeKeyFromMinutes(mulaiMenit);

  String get jamSelesai => DateTimeUtils.timeKeyFromMinutes(selesaiMenit);

  int get durasiMenit => selesaiMenit - mulaiMenit;

  String get label => DateTimeUtils.formatRentangJam(jamMulai, jamSelesai);

  String get durasiLabel => DateTimeUtils.formatDurasi(durasiMenit);

  @override
  String toString() => 'TimeRange($label)';
}

/// Ketersediaan satu laboratorium pada satu tanggal.
class LabDayAvailability {
  const LabDayAvailability({
    required this.idLab,
    required this.namaLab,
    required this.tanggal,
    required this.slots,
    required this.jamBukaMenit,
    required this.jamTutupMenit,
  });

  final int idLab;
  final String namaLab;
  final String tanggal;

  /// Seluruh slot terpakai (termasuk yang belum disetujui).
  final List<OccupancySlot> slots;

  final int jamBukaMenit;
  final int jamTutupMenit;

  /// Slot yang benar-benar menghalangi pengajuan baru.
  List<OccupancySlot> get slotMemblokir =>
      slots.where((slot) => slot.memblokirReservasi).toList(growable: false);

  /// Pengajuan yang masih menunggu verifikasi pada hari tersebut.
  List<OccupancySlot> get slotMenunggu => slots
      .where((slot) => slot.source == OccupancySource.reservasiMenunggu)
      .toList(growable: false);

  bool get adaSlotTerpakai => slotMemblokir.isNotEmpty;

  bool get penuh => rentangKosong.isEmpty;

  /// Rentang waktu yang masih bisa dipesan pada hari tersebut.
  List<TimeRange> get rentangKosong => computeFreeRanges(
    blocking: slotMemblokir,
    dayStartMinutes: jamBukaMenit,
    dayEndMinutes: jamTutupMenit,
  );

  int get totalMenitKosong =>
      rentangKosong.fold(0, (total, range) => total + range.durasiMenit);

  /// Menghitung rentang waktu bebas dari sekumpulan slot yang memblokir.
  ///
  /// Algoritma:
  /// 1. Buang slot di luar jam operasional, urutkan berdasarkan jam mulai.
  /// 2. Gabungkan slot yang saling bersinggungan / tumpang tindih.
  /// 3. Selisih antara jam operasional dengan slot gabungan = waktu kosong.
  static List<TimeRange> computeFreeRanges({
    required List<OccupancySlot> blocking,
    required int dayStartMinutes,
    required int dayEndMinutes,
  }) {
    if (dayEndMinutes <= dayStartMinutes) return const <TimeRange>[];

    final relevan = blocking
        .where(
          (slot) =>
              slot.selesaiMenit > dayStartMinutes &&
              slot.mulaiMenit < dayEndMinutes,
        )
        .toList()
      ..sort((a, b) => a.mulaiMenit.compareTo(b.mulaiMenit));

    final hasil = <TimeRange>[];
    var kursor = dayStartMinutes;

    for (final slot in relevan) {
      final mulai = slot.mulaiMenit.clamp(dayStartMinutes, dayEndMinutes);
      final selesai = slot.selesaiMenit.clamp(dayStartMinutes, dayEndMinutes);

      if (mulai > kursor) {
        hasil.add(TimeRange(mulaiMenit: kursor, selesaiMenit: mulai));
      }
      if (selesai > kursor) kursor = selesai;
    }

    if (kursor < dayEndMinutes) {
      hasil.add(TimeRange(mulaiMenit: kursor, selesaiMenit: dayEndMinutes));
    }

    return hasil;
  }
}
