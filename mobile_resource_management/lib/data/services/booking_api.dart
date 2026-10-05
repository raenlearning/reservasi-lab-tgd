import '../../core/utils/json_utils.dart';
import '../models/booking.dart';
import '../models/lab_schedule.dart';
import 'api_client.dart';

/// Pengajuan reservasi.
///
/// ### Pencegahan double booking ada di server, bukan di sini
///
/// Endpoint `POST /bookings` memeriksa bentrok di dalam `DB::transaction` dengan
/// `lockForUpdate()`, lalu mengembalikan:
///
/// * **201** — berhasil dibuat, status awal `Menunggu`
/// * **422** — slot sudah terpakai, dengan pesan yang siap ditampilkan
///
/// Klien **tidak** perlu memeriksa bentrok lebih dulu. Pemeriksaan di sisi
/// klien hanya berguna untuk memberi umpan balik cepat sebelum tombol ditekan —
/// dan itu tidak boleh dianggap sebagai jaminan, karena bisa saja data sudah
/// berubah sejak terakhir dimuat.
class BookingApi {
  BookingApi({ApiClient? klien}) : _klien = klien ?? ApiClient();

  final ApiClient _klien;

  /// Daftar pengajuan.
  ///
  /// Mahasiswa/Dosen menerima pengajuannya sendiri; Kepala Laboratorium
  /// menerima seluruhnya beserta identitas pemohon.
  Future<List<Booking>> daftar({
    String? status,
    int? labId,
    String? tanggal,
    String? dari,
    String? sampai,
  }) async {
    final respons = await _klien.get(
      '/bookings',
      query: {
        'status': ?status,
        'lab_id': ?labId?.toString(),
        'tanggal': ?tanggal,
        'dari': ?dari,
        'sampai': ?sampai,
      },
    );

    return Json.asMapList(Json.asMap(respons)['data'])
        .map(Booking.fromJson)
        .toList(growable: false);
  }

  /// Membuat pengajuan baru.
  ///
  /// Melempar [AppException] dengan kode `scheduleConflict` bila slot bentrok —
  /// lihat `AppException.dariRespons()`.
  Future<Booking> ajukan(BookingDraft draft) async {
    final respons = await _klien.post('/bookings', body: draft.toJson());

    return Booking.fromJson(Json.asMap(Json.asMap(respons)['data']));
  }

  /// Menyetujui atau menolak pengajuan. Hanya Kepala Laboratorium.
  Future<Booking> verifikasi({
    required int bookingId,
    required bool disetujui,
    String? alasanPenolakan,
  }) async {
    final respons = await _klien.patch(
      '/bookings/$bookingId/review',
      body: {
        'disetujui': disetujui,
        if (!disetujui) 'alasan_penolakan': alasanPenolakan,
      },
    );

    return Booking.fromJson(Json.asMap(Json.asMap(respons)['data']));
  }

  /// Membatalkan pengajuan yang masih menunggu. Hanya pemiliknya.
  Future<void> batalkan(int bookingId) => _klien.delete('/bookings/$bookingId');
}

/// Hasil penyimpanan jadwal acuan.
///
/// Berisi jadwal yang berhasil dibuat beserta minggu yang **dilewati** karena
/// sudah terisi pengajuan aktif. Server sengaja tidak membatalkan seluruh
/// rentang hanya karena satu minggu bentrok.
class HasilSimpanJadwal {
  const HasilSimpanJadwal({required this.dibuat, required this.dilewati});

  final List<LabSchedule> dibuat;
  final List<JadwalDilewati> dilewati;

  int get jumlahDibuat => dibuat.length;
  int get jumlahDilewati => dilewati.length;
}

/// Satu minggu yang tidak jadi dibuat karena rentangnya sudah terisi.
class JadwalDilewati {
  const JadwalDilewati({required this.tanggal, required this.alasan});

  /// `yyyy-MM-dd`.
  final String tanggal;

  /// Pesan dari server, siap ditampilkan.
  final String alasan;

  factory JadwalDilewati.fromJson(Map<String, dynamic> json) => JadwalDilewati(
    tanggal: json['tanggal']?.toString() ?? '',
    alasan: json['alasan']?.toString() ?? '',
  );
}

/// Jadwal acuan laboratorium.
class JadwalApi {
  JadwalApi({ApiClient? klien}) : _klien = klien ?? ApiClient();

  final ApiClient _klien;

  Future<List<LabSchedule>> daftar({
    String? dari,
    String? sampai,
    int? labId,
  }) async {
    final respons = await _klien.get(
      '/schedules',
      query: {
        'dari': ?dari,
        'sampai': ?sampai,
        'lab_id': ?labId?.toString(),
      },
    );

    return Json.asMapList(Json.asMap(respons)['data'])
        .map(LabSchedule.fromJson)
        .toList(growable: false);
  }

  /// Menyimpan jadwal — menambah (`id == 0`) atau mengubah.
  ///
  /// Bila [ulangiSampai] diisi untuk jadwal **baru**, server membuat jadwal
  /// berulang setiap 7 hari dari `jadwal.tanggal` sampai tanggal tersebut.
  /// Setiap kemunculan tetap menjadi baris tersendiri.
  ///
  /// Mengubah jadwal yang sudah ada selalu satu baris — pengulangan diabaikan.
  Future<HasilSimpanJadwal> simpan(
    LabSchedule jadwal, {
    String? ulangiSampai,
  }) async {
    if (jadwal.id != 0) {
      final respons = await _klien.put(
        '/schedules/${jadwal.id}',
        body: jadwal.toJson(),
      );

      return HasilSimpanJadwal(
        dibuat: [LabSchedule.fromJson(Json.asMap(Json.asMap(respons)['data']))],
        dilewati: const [],
      );
    }

    final respons = await _klien.post(
      '/schedules',
      body: {...jadwal.toJson(), 'ulangi_sampai': ?ulangiSampai},
    );

    final map = Json.asMap(respons);

    return HasilSimpanJadwal(
      dibuat: Json.asMapList(map['data'])
          .map(LabSchedule.fromJson)
          .toList(growable: false),
      dilewati: Json.asMapList(map['dilewati'])
          .map(JadwalDilewati.fromJson)
          .toList(growable: false),
    );
  }

  Future<void> hapus(int id) => _klien.delete('/schedules/$id');
}
