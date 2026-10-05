import '../../core/utils/json_utils.dart';

/// Laboratorium yang dapat direservasi.
class Lab {
  const Lab({
    required this.id,
    required this.namaLab,
    required this.kapasitas,
    this.lokasi,
    this.fasilitas = const [],
    this.isActive = true,
  });

  final int id;
  final String namaLab;
  final int kapasitas;
  final String? lokasi;

  /// Daftar fasilitas. Di MySQL disimpan sebagai kolom JSON, dan Laravel
  /// mengembalikannya sudah berbentuk array.
  final List<String> fasilitas;

  final bool isActive;

  factory Lab.fromJson(Map<String, dynamic> json) {
    return Lab(
      id: Json.asInt(json['id']),
      namaLab: json['nama_lab']?.toString() ?? '',
      kapasitas: Json.asInt(json['kapasitas']),
      lokasi: json['lokasi']?.toString(),
      fasilitas: Json.asList(json['fasilitas'])
          .map((e) => e.toString())
          .toList(growable: false),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'nama_lab': namaLab,
    'kapasitas': kapasitas,
    'lokasi': lokasi,
    'fasilitas': fasilitas,
    'is_active': isActive,
  };

  String get kapasitasLabel => '$kapasitas kursi';

  @override
  String toString() => 'Lab($id, $namaLab)';
}
