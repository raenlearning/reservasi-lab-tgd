import '../../core/utils/json_utils.dart';
import 'enums.dart';
import 'lab.dart';

/// Pengajuan reservasi kelas pengganti.
class Booking {
  const Booking({
    required this.id,
    required this.idUser,
    required this.idLab,
    required this.mataKuliah,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.status,
    this.catatan,
    this.alasanPenolakan,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.namaPemohon,
    this.nomorIdentitasPemohon,
    this.lab,
  });

  final int id;
  final int idUser;
  final int idLab;
  final String mataKuliah;

  /// `yyyy-MM-dd`.
  final String tanggal;

  /// `HH:mm`.
  final String jamMulai;
  final String jamSelesai;

  final BookingStatus status;
  final String? catatan;
  final String? alasanPenolakan;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  /// Identitas pemohon — hanya dikirim server kepada Kepala Laboratorium.
  final String? namaPemohon;
  final String? nomorIdentitasPemohon;

  final Lab? lab;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: Json.asInt(json['id']),
      idUser: Json.asInt(json['user_id']),
      idLab: Json.asInt(json['lab_id']),
      mataKuliah: json['mata_kuliah']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      jamMulai: json['jam_mulai']?.toString() ?? '00:00',
      jamSelesai: json['jam_selesai']?.toString() ?? '00:00',
      status: BookingStatus.fromLabel(json['status']),
      catatan: json['catatan']?.toString(),
      alasanPenolakan: json['alasan_penolakan']?.toString(),
      reviewedBy: Json.asIntOrNull(json['reviewed_by']),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      namaPemohon: json['nama_pemohon']?.toString(),
      nomorIdentitasPemohon: json['nomor_identitas_pemohon']?.toString(),
      lab: json['lab'] is Map<String, dynamic>
          ? Lab.fromJson(json['lab'] as Map<String, dynamic>)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Turunan
  // ---------------------------------------------------------------------------

  int get mulaiMenit => _keMenit(jamMulai);
  int get selesaiMenit => _keMenit(jamSelesai);
  int get durasiMenit => selesaiMenit - mulaiMenit;

  String get rentangJam => '$jamMulai – $jamSelesai';

  /// Tanggal pengajuan sebagai [DateTime].
  ///
  /// Memakai `tryParse`, bukan `parse`: bila server tidak mengirim tanggal yang
  /// sah, `parse` melempar `FormatException` dan mematikan seluruh layar yang
  /// merendernya (kartu pengajuan, detail, sampai pengurutan daftar). Nilai
  /// 1 Januari 1970 dipakai sebagai penanda "tanggal tidak diketahui".
  DateTime get tanggalDateTime => DateTime.tryParse(tanggal) ?? DateTime(1970);

  bool get sudahLewat => tanggalDateTime.isBefore(
    DateTime.now().subtract(const Duration(days: 1)),
  );

  /// Pemohon masih boleh membatalkan selama statusnya Menunggu.
  bool get bisaDibatalkan => status.isMenunggu;

  /// Apakah pengajuan ini menahan slot.
  ///
  /// Baik `Menunggu` maupun `Disetujui` menahan slot — itu inti pencegahan
  /// double booking di sisi server. Hanya `Ditolak` yang melepas slotnya.
  bool get menahanSlot =>
      status.isMenunggu || status.isDisetujui;

  static int _keMenit(String jam) {
    final bagian = jam.split(':');
    if (bagian.length < 2) return 0;
    return (int.tryParse(bagian[0]) ?? 0) * 60 + (int.tryParse(bagian[1]) ?? 0);
  }

  @override
  String toString() => 'Booking($id, $tanggal $rentangJam, ${status.label})';
}

/// Data yang dikirim saat membuat pengajuan baru.
///
/// Terpisah dari [Booking] karena klien tidak boleh menentukan `id`, `status`,
/// maupun field verifikasi — semuanya ditetapkan server.
class BookingDraft {
  const BookingDraft({
    required this.idLab,
    required this.mataKuliah,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    this.catatan,
  });

  final int idLab;
  final String mataKuliah;
  final String tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String? catatan;

  Map<String, dynamic> toJson() => {
    'lab_id': idLab,
    'mata_kuliah': mataKuliah,
    'tanggal': tanggal,
    'jam_mulai': jamMulai,
    'jam_selesai': jamSelesai,
    if (catatan != null && catatan!.trim().isNotEmpty) 'catatan': catatan!.trim(),
  };
}
