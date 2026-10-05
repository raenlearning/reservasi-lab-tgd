import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Peran pengguna — memetakan kolom `jabatan ENUM('Dosen','Mahasiswa','Kepala Lab')`
/// pada rancangan tabel `users`.
enum UserRole {
  mahasiswa('Mahasiswa', 'Mahasiswa', Icons.school_outlined),
  dosen('Dosen', 'Dosen', Icons.badge_outlined),
  kepalaLab('Kepala Lab', 'Kepala Laboratorium', Icons.admin_panel_settings_outlined);

  const UserRole(this.label, this.description, this.icon);

  /// Nilai yang disimpan di Firestore (harus sama persis dengan ENUM di DDL).
  final String label;

  /// Label panjang untuk ditampilkan di UI.
  final String description;

  final IconData icon;

  bool get isAdmin => this == UserRole.kepalaLab;
  static const List<UserRole> selfRegistrable = [mahasiswa, dosen];

  static UserRole? tryFromLabel(Object? value) {
    final normalized = (value?.toString() ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final role in UserRole.values) {
      if (role.label.toLowerCase() == normalized) return role;
    }
    return null;
  }

  /// Seperti [tryFromLabel], tetapi mengembalikan [UserRole.mahasiswa] bila
  /// nilainya tidak dikenali — supaya antarmuka tetap dapat dirender.
  ///
  /// Gunakan `AppUser.jabatanDikenali` untuk mendeteksi ketidakcocokan dan
  /// menampilkannya kepada pengguna.
  static UserRole fromLabel(Object? value) =>
      tryFromLabel(value) ?? UserRole.mahasiswa;
}

/// Status pengajuan — memetakan `status ENUM('Menunggu','Disetujui','Ditolak')`.
enum BookingStatus {
  menunggu('Menunggu', AppColors.statusMenungguFg, AppColors.statusMenungguBg, Icons.hourglass_top_rounded),
  disetujui('Disetujui', AppColors.statusDisetujuiFg, AppColors.statusDisetujuiBg, Icons.check_circle_outline_rounded),
  ditolak('Ditolak', AppColors.statusDitolakFg, AppColors.statusDitolakBg, Icons.cancel_outlined);

  const BookingStatus(this.label, this.foreground, this.background, this.icon);

  final String label;
  final Color foreground;
  final Color background;
  final IconData icon;

  bool get isMenunggu => this == BookingStatus.menunggu;
  bool get isDisetujui => this == BookingStatus.disetujui;
  bool get isDitolak => this == BookingStatus.ditolak;

  /// Status akhir — tidak bisa diubah lagi.
  bool get isFinal => this != BookingStatus.menunggu;

  /// Apakah slot pada status ini dianggap "terpakai" pada kalender ketersediaan.
  bool get occupiesSlot => this == BookingStatus.disetujui;

  static BookingStatus fromLabel(Object? value) {
    final normalized = (value?.toString() ?? '').trim().toLowerCase();
    for (final status in BookingStatus.values) {
      if (status.label.toLowerCase() == normalized) return status;
      if (status.name.toLowerCase() == normalized) return status;
    }
    return BookingStatus.menunggu;
  }
}

/// Jenis entri jadwal pada koleksi `lab_schedules`.
enum ScheduleType {
  reguler('Reguler', AppColors.slotReguler, Icons.event_available_outlined),
  pengganti('Pengganti', AppColors.slotPengganti, Icons.event_repeat_outlined),
  pemeliharaan('Pemeliharaan', AppColors.slotPemeliharaan, Icons.build_outlined);

  const ScheduleType(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  /// Blokir jadwal: tidak boleh ada reservasi baru pada rentang ini.
  bool get blocksBooking =>
      this == ScheduleType.reguler || this == ScheduleType.pemeliharaan;

  static ScheduleType fromLabel(Object? value) {
    final normalized = (value?.toString() ?? '').trim().toLowerCase();
    for (final type in ScheduleType.values) {
      if (type.label.toLowerCase() == normalized) return type;
      if (type.name.toLowerCase() == normalized) return type;
    }
    return ScheduleType.reguler;
  }
}

/// Asal-usul sebuah slot pada kalender ketersediaan.
enum OccupancySource {
  jadwalReguler(
    'Jadwal Reguler',
    Icons.event_available_outlined,
    AppColors.slotReguler,
  ),
  jadwalPemeliharaan(
    'Pemeliharaan',
    Icons.build_outlined,
    AppColors.slotPemeliharaan,
  ),
  reservasiDisetujui(
    'Kelas Pengganti',
    Icons.event_repeat_outlined,
    AppColors.slotPengganti,
  ),
  reservasiMenunggu(
    'Menunggu Verifikasi',
    Icons.hourglass_top_rounded,
    AppColors.slotMenunggu,
  );

  const OccupancySource(this.label, this.icon, this.color);

  final String label;
  final IconData icon;

  /// Warna penanda slot pada kalender, kartu ketersediaan, dan timeline jadwal.
  final Color color;

  /// Slot ini menahan pengajuan baru.
  ///
  /// Baik pengajuan yang sudah disetujui **maupun yang masih menunggu** menahan
  /// slot. Ini mengikuti aturan di server: begitu seseorang mengajukan sebuah
  /// slot, slot itu terkunci sampai Kepala Laboratorium memutuskan. Kalau
  /// `reservasiMenunggu` tidak dihitung menahan, kalender akan menampilkan slot
  /// sebagai kosong padahal pengajuan baru ke sana akan ditolak server — dan
  /// pengguna mengira aplikasinya rusak.
  bool get blocksBooking => true;
}
