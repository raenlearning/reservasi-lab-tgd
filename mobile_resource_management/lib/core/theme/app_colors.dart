import 'package:flutter/material.dart';

/// Palet warna aplikasi.
///
/// Warna dasar (seed) sengaja dipilih biru-navy akademik dengan aksen teal,
/// supaya terasa institusional namun tetap modern dan "clean" sesuai kebutuhan
/// non-fungsional pada dokumen (Usability & Clean Design).
class AppColors {
  const AppColors._();

  // Warna merek
  static const Color primary = Color(0xFF12447A);
  static const Color primaryDark = Color(0xFF0B2E54);
  static const Color primaryLight = Color(0xFF3D6EA8);
  static const Color secondary = Color(0xFF0E8C7F);
  static const Color secondaryLight = Color(0xFFD6F1ED);
  static const Color accent = Color(0xFFE0A83C);

  // Netral
  static const Color surface = Color(0xFFF7F9FC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDCE3ED);
  static const Color textPrimary = Color(0xFF16202E);
  static const Color textSecondary = Color(0xFF5A6879);
  static const Color textDisabled = Color(0xFF9AA6B6);

  // Netral (mode gelap)
  static const Color surfaceDark = Color(0xFF101822);
  static const Color surfaceCardDark = Color(0xFF1A2431);
  static const Color borderDark = Color(0xFF2C3949);
  static const Color textPrimaryDark = Color(0xFFEDF2F8);
  static const Color textSecondaryDark = Color(0xFFA9B6C6);

  // Semantik status pengajuan
  static const Color statusMenungguFg = Color(0xFF8A5300);
  static const Color statusMenungguBg = Color(0xFFFFF3DC);
  static const Color statusDisetujuiFg = Color(0xFF14653C);
  static const Color statusDisetujuiBg = Color(0xFFE2F5EA);
  static const Color statusDitolakFg = Color(0xFFA32018);
  static const Color statusDitolakBg = Color(0xFFFCE8E6);

  // Semantik umum
  static const Color success = Color(0xFF1B7F4B);
  static const Color warning = Color(0xFFB26A00);
  static const Color danger = Color(0xFFB3261E);
  static const Color info = Color(0xFF1B6FC4);

  // Warna sumber slot pada kalender
  static const Color slotReguler = Color(0xFF12447A);
  static const Color slotPengganti = Color(0xFF0E8C7F);
  static const Color slotPemeliharaan = Color(0xFF8A5300);
  static const Color slotMenunggu = Color(0xFF6B7A8F);
  static const Color slotKosong = Color(0xFFE2F5EA);
}
