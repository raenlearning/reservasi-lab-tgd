import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// Pengguna sistem.
///
/// Berbeda dari versi Firebase yang memakai UID string, kini identitasnya
/// bilangan bulat dari kolom `id` MySQL. Login memakai [nomorIdentitas]
/// (NIM/NIDN) — tanpa perantara email seperti yang diwajibkan Firebase Auth.
class AppUser {
  const AppUser({
    required this.id,
    required this.nomorIdentitas,
    required this.nama,
    required this.jabatan,
    required this.isActive,
  });

  final int id;
  final String nomorIdentitas;
  final String nama;

  /// Nilai `jabatan` apa adanya dari server.
  ///
  /// Disimpan mentah, bukan langsung dipetakan ke enum, supaya nilai yang tidak
  /// dikenal dapat ditampilkan apa adanya di layar profil — bukan diam-diam
  /// berubah menjadi peran lain.
  final String jabatan;

  final bool isActive;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: Json.asInt(json['id']),
      nomorIdentitas: json['nomor_identitas']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      jabatan: json['jabatan']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nomor_identitas': nomorIdentitas,
    'nama': nama,
    'jabatan': jabatan,
    'is_active': isActive,
  };

  // ---------------------------------------------------------------------------
  // Peran
  // ---------------------------------------------------------------------------

  /// Peran hasil pemetaan [jabatan]. Nilai tak dikenal jatuh ke Mahasiswa.
  UserRole get role => UserRole.fromLabel(jabatan);

  /// `false` bila [jabatan] bukan salah satu nilai yang dikenal server.
  ///
  /// Nilai harus persis `Mahasiswa`, `Dosen`, atau `Kepala Lab`.
  bool get jabatanDikenali => UserRole.tryFromLabel(jabatan) != null;

  String get jabatanLabel => role.label;

  bool get isAdmin => role.isAdmin;

  /// Dua huruf pertama nama, untuk avatar.
  String get inisial {
    final bagian = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((b) => b.isNotEmpty)
        .take(2);

    return bagian.map((b) => b[0].toUpperCase()).join();
  }

  @override
  String toString() => 'AppUser($id, $nomorIdentitas, $nama, $jabatan)';
}
