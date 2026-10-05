import '../../core/utils/json_utils.dart';
import '../models/booking.dart';
import '../models/lab.dart';
import '../models/lab_schedule.dart';
import 'api_client.dart';

/// Satu potret ketersediaan laboratorium pada satu rentang tanggal.
///
/// Dikembalikan oleh `/api/calendar` dalam **satu** permintaan — laboratorium,
/// jadwal, dan slot terpakai sekaligus. Ini yang membuat *short polling* hemat:
/// satu siklus hanya menghasilkan satu panggilan HTTP, bukan tiga.
class SnapshotKalender {
  const SnapshotKalender({
    required this.dari,
    required this.sampai,
    required this.labs,
    required this.schedules,
    required this.bookings,
  });

  final String dari;
  final String sampai;
  final List<Lab> labs;
  final List<LabSchedule> schedules;

  /// Slot yang terpakai. Tidak memuat identitas pemohon — server sengaja
  /// mengirim versi ringkas agar data pribadi tidak bocor lewat endpoint ini.
  final List<Booking> bookings;

  static const SnapshotKalender kosong = SnapshotKalender(
    dari: '',
    sampai: '',
    labs: [],
    schedules: [],
    bookings: [],
  );

  factory SnapshotKalender.fromJson(Map<String, dynamic> json) {
    return SnapshotKalender(
      dari: json['dari']?.toString() ?? '',
      sampai: json['sampai']?.toString() ?? '',
      labs: Json.asMapList(json['labs'])
          .map(Lab.fromJson)
          .toList(growable: false),
      schedules: Json.asMapList(json['schedules'])
          .map(LabSchedule.fromJson)
          .toList(growable: false),
      bookings: Json.asMapList(json['bookings'])
          .map(Booking.fromJson)
          .toList(growable: false),
    );
  }
}

/// Kalender ketersediaan.
class KalenderApi {
  KalenderApi({ApiClient? klien}) : _klien = klien ?? ApiClient();

  final ApiClient _klien;

  /// Mengambil ketersediaan pada rentang tanggal.
  ///
  /// Ini endpoint yang dipanggil berulang oleh `Timer.periodic`.
  Future<SnapshotKalender> ambil({
    required String dari,
    required String sampai,
    int? labId,
  }) async {
    final respons = await _klien.get(
      '/calendar',
      query: {
        'dari': dari,
        'sampai': sampai,
        if (labId != null) 'lab_id': labId.toString(),
      },
    );

    return SnapshotKalender.fromJson(Json.asMap(respons));
  }

  /// Daftar laboratorium saja — dipakai saat kalender belum perlu dimuat.
  Future<List<Lab>> daftarLab({bool termasukNonaktif = false}) async {
    final respons = await _klien.get(
      '/labs',
      query: {if (termasukNonaktif) 'termasuk_nonaktif': '1'},
    );

    return Json.asMapList(Json.asMap(respons)['data'])
        .map(Lab.fromJson)
        .toList(growable: false);
  }
}
