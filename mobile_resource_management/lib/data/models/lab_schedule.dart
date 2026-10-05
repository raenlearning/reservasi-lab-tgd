import '../../core/utils/json_utils.dart';
import 'enums.dart';
import 'lab.dart';

/// Jadwal acuan laboratorium.
///
/// Tipe `Reguler` dan `Pemeliharaan` memblokir slot sehingga tidak dapat
/// diajukan sebagai kelas pengganti. Tipe `Pengganti` tidak memblokir.
class LabSchedule {
  const LabSchedule({
    required this.id,
    required this.idLab,
    required this.mataKuliah,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.tipe,
    this.namaDosen,
    this.semester,
    this.catatan,
    this.lab,
  });

  final int id;
  final int idLab;
  final String mataKuliah;

  /// `yyyy-MM-dd`.
  final String tanggal;

  /// `HH:mm`.
  final String jamMulai;
  final String jamSelesai;

  final ScheduleType tipe;
  final String? namaDosen;
  final String? semester;
  final String? catatan;

  /// Terisi bila server menyertakan relasinya.
  final Lab? lab;

  factory LabSchedule.fromJson(Map<String, dynamic> json) {
    return LabSchedule(
      id: Json.asInt(json['id']),
      idLab: Json.asInt(json['lab_id']),
      mataKuliah: json['mata_kuliah']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      jamMulai: json['jam_mulai']?.toString() ?? '00:00',
      jamSelesai: json['jam_selesai']?.toString() ?? '00:00',
      tipe: ScheduleType.fromLabel(json['tipe']),
      namaDosen: json['nama_dosen']?.toString(),
      semester: json['semester']?.toString(),
      catatan: json['catatan']?.toString(),
      lab: json['lab'] is Map<String, dynamic>
          ? Lab.fromJson(json['lab'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Payload untuk POST/PUT — hanya field yang boleh diubah klien.
  Map<String, dynamic> toJson() => {
    'lab_id': idLab,
    'mata_kuliah': mataKuliah,
    'nama_dosen': namaDosen,
    'tanggal': tanggal,
    'jam_mulai': jamMulai,
    'jam_selesai': jamSelesai,
    'tipe': tipe.label,
    'semester': semester,
    'catatan': catatan,
  };

  /// Menit sejak tengah malam.
  int get mulaiMenit => _keMenit(jamMulai);
  int get selesaiMenit => _keMenit(jamSelesai);

  String get rentangJam => '$jamMulai – $jamSelesai';

  /// Apakah jadwal ini menahan slot.
  bool get memblokirSlot => tipe.blocksBooking;

  /// Tanggal jadwal sebagai [DateTime].
  ///
  /// Memakai `tryParse` supaya tanggal yang kosong atau rusak tidak melempar
  /// `FormatException` di tengah perenderan. 1 Januari 1970 menandai tanggal
  /// yang tidak diketahui.
  DateTime get tanggalDateTime => DateTime.tryParse(tanggal) ?? DateTime(1970);

  static int _keMenit(String jam) {
    final bagian = jam.split(':');
    if (bagian.length < 2) return 0;
    return (int.tryParse(bagian[0]) ?? 0) * 60 + (int.tryParse(bagian[1]) ?? 0);
  }

  @override
  String toString() => 'LabSchedule($id, $tanggal $rentangJam, $mataKuliah)';
}
