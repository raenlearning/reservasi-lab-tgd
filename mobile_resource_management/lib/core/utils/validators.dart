import 'package:flutter/services.dart';

import '../config/app_config.dart';
import 'identity_utils.dart';

class Validators {
  const Validators._();

  static String? nomorIdentitas(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'NIM/NIDN wajib diisi.';
    if (!IdentityUtils.looksLikeIdentityNumber(input)) {
      return 'NIM/NIDN harus berupa 6-15 digit angka tanpa spasi.';
    }
    return null;
  }

  static String? nama(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'Nama lengkap wajib diisi.';
    if (input.length < 3) return 'Nama lengkap minimal 3 karakter.';
    if (input.length > 100) return 'Nama lengkap maksimal 100 karakter.';
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Kata sandi wajib diisi.';
    if (input.length < AppConfig.minPasswordLength) {
      return 'Kata sandi minimal ${AppConfig.minPasswordLength} karakter.';
    }
    return null;
  }

  static String? konfirmasiPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Konfirmasi kata sandi wajib diisi.';
    if (value != password) return 'Konfirmasi kata sandi tidak sama.';
    return null;
  }

  static String? mataKuliah(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'Mata kuliah wajib diisi.';
    if (input.length < 3) return 'Nama mata kuliah minimal 3 karakter.';
    if (input.length > 100) return 'Nama mata kuliah maksimal 100 karakter.';
    return null;
  }

  static String? kapasitas(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'Kapasitas wajib diisi.';
    final parsed = int.tryParse(input);
    if (parsed == null) return 'Kapasitas harus berupa angka.';
    if (parsed < 1) return 'Kapasitas minimal 1 orang.';
    if (parsed > 500) return 'Kapasitas maksimal 500 orang.';
    return null;
  }

  static String? namaLab(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'Nama laboratorium wajib diisi.';
    if (input.length > 50) return 'Nama laboratorium maksimal 50 karakter.';
    return null;
  }

  static String? catatan(String? value, {int maxLength = 500}) {
    final input = (value ?? '').trim();
    if (input.length > maxLength) {
      return 'Catatan maksimal $maxLength karakter.';
    }
    return null;
  }
}

class AppInputFormatters {
  const AppInputFormatters._();

  static final List<TextInputFormatter> digitsOnly = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  static final List<TextInputFormatter> uppercaseLettersAndSpaces = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-_/( )]')),
  ];
}
